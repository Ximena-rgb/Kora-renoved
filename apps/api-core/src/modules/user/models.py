"""
modules/user/models.py
=======================
Modelo central de usuario.
- Sin contraseña propia (autenticación vía Google/Firebase)
- firebase_uid para vincular cuenta Google
- TOTP MFA opcional
- Horarios semanales para Cross-Schedule Matching
"""
from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.contrib.postgres.fields import ArrayField
from django.db import models


class UserManager(BaseUserManager):
    def create_user_from_google(self, email: str, firebase_uid: str, nombre: str, foto_url: str = '', **extra_fields):
        """Crea usuario desde Google Sign-In. Sin contraseña local."""
        if not email:
            raise ValueError('El correo es obligatorio')
        email = self.normalize_email(email)
        user  = self.model(
            email        = email,
            firebase_uid = firebase_uid,
            nombre       = nombre,
            foto_url     = foto_url,
            **extra_fields,
        )
        # Contraseña inutilizable — auth es 100% via Firebase/JWT
        user.set_unusable_password()
        user.save(using=self._db)
        return user

    def create_superuser(self, email, password=None, **extra_fields):
        """Solo para acceso al admin de Django en desarrollo."""
        extra_fields.setdefault('is_staff', True)
        extra_fields.setdefault('is_superuser', True)
        email = self.normalize_email(email)
        user  = self.model(email=email, firebase_uid='admin', nombre='Admin', **extra_fields)
        user.set_password(password)
        user.save(using=self._db)
        return user


class User(AbstractBaseUser, PermissionsMixin):

    # ── Identidad ─────────────────────────────────────────────────
    email        = models.EmailField(unique=True)
    firebase_uid = models.CharField(max_length=128, unique=True, db_index=True)
    nombre       = models.CharField(max_length=120)
    foto_url     = models.URLField(blank=True, default='')

    # ── Perfil académico (se completa después del primer login) ───
    carrera   = models.CharField(max_length=120, blank=True, default='')
    facultad  = models.CharField(max_length=120, blank=True, default='')
    semestre  = models.PositiveSmallIntegerField(default=1)
    bio       = models.TextField(max_length=300, blank=True, default='')
    intereses = ArrayField(
        models.CharField(max_length=60), default=list, blank=True
    )

    # ── Disponibilidad ────────────────────────────────────────────
    campus_zona = models.CharField(max_length=80, blank=True, default='')
    disponible  = models.BooleanField(default=False)

    # ── Horarios (Cross-Schedule Matching) ───────────────────────
    horarios = models.JSONField(
        default=list, blank=True,
        help_text='[{"dia":"lunes","inicio":"08:00","fin":"10:00"}]'
    )

    # ── Reputación ────────────────────────────────────────────────
    reputacion    = models.DecimalField(max_digits=3, decimal_places=2, default=0.00)
    total_ratings = models.PositiveIntegerField(default=0)

    # ── MFA (TOTP) ────────────────────────────────────────────────
    mfa_activo     = models.BooleanField(default=False)
    mfa_secret     = models.CharField(max_length=64, blank=True, default='',
                        help_text='Secret TOTP — encriptado en producción')
    mfa_backup_codes = models.JSONField(default=list, blank=True,
                        help_text='Códigos de respaldo hasheados')

    # ── Estado del perfil ─────────────────────────────────────────
    perfil_completo = models.BooleanField(default=False,
                        help_text='True después de completar carrera/semestre')

    # ── Permisos Django ───────────────────────────────────────────
    is_active = models.BooleanField(default=True)
    is_staff  = models.BooleanField(default=False)

    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    objects = UserManager()

    USERNAME_FIELD  = 'email'
    REQUIRED_FIELDS = ['nombre']

    class Meta:
        app_label = 'kora_user'
        db_table  = 'users'
        ordering  = ['-created_at']

    def __str__(self):
        return f'{self.nombre} <{self.email}>'

    def actualizar_reputacion(self, nueva_nota: float):
        total = float(self.reputacion) * self.total_ratings + nueva_nota
        self.total_ratings += 1
        self.reputacion = round(total / self.total_ratings, 2)
        self.save(update_fields=['reputacion', 'total_ratings'])
