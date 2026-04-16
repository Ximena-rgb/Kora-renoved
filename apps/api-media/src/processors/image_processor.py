"""
processors/image_processor.py
================================
Pipeline de procesamiento seguro de imágenes para Kora.

Orden de validaciones (fail-fast):
  1. Antivirus básico — magic bytes, entropía, tamaño
  2. Eliminar metadata EXIF completa
  3. Verificar que es imagen válida y decodificable
  4. Verificar rostro visible (obligatorio para fotos de perfil)
  5. Verificar coincidencia de género (hombre→hombre, mujer→mujer)
  6. NSFW check (nudenet opcional)
  7. Resize + compresión WebP
  8. Guardar sin metadata
"""

import logging
import os
import struct
import math
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageOps

logger = logging.getLogger(__name__)

MAX_FILE_MB    = 15
WEBP_QUALITY   = 85
NSFW_THRESHOLD = 0.55

SIZES = {
    'profile': [
        ('original', (1080, 1080)),
        ('medium',   (400,  400)),
        ('thumb',    (120,  120)),
    ],
    'plans': [
        ('original', (1200, 800)),
        ('medium',   (600,  400)),
        ('thumb',    (200,  133)),
    ],
}

NSFW_REJECT = {
    'FEMALE_GENITALIA_EXPOSED', 'MALE_GENITALIA_EXPOSED',
    'FEMALE_BREAST_EXPOSED', 'ANUS_EXPOSED', 'SEXUAL_ACTIVITY',
    'FEMALE_BREAST_COVERED', 'BUTTOCKS_EXPOSED',
}

# Magic bytes de formatos de imagen válidos
VALID_MAGIC = {
    b'\xff\xd8\xff':       'jpeg',
    b'\x89PNG':            'png',
    b'RIFF':               'webp',  # RIFF????WEBP
    b'GIF8':               'gif',
    b'BM':                 'bmp',
}


class ValidationError(ValueError):
    """Error de validación — la foto no cumple los requisitos."""
    pass


class ImageProcessor:

    def __init__(self, storage_root: str):
        self.storage_root = Path(storage_root)

    def process(self, tmp_path: str, user_id: int, tipo: str, filename: str,
                genero_usuario: str = '') -> dict:
        """
        Procesa y valida una imagen de perfil.

        genero_usuario: 'masculino' | 'femenino' | '' (vacío = sin validación de género)

        Retorna: { 'urls': {...}, 'foto_url': '...' }
        Lanza ValidationError si no pasa alguna validación.
        """
        tmp = Path(tmp_path)
        if not tmp.exists():
            raise FileNotFoundError(f'Archivo no encontrado: {tmp_path}')

        # ── 1. Antivirus básico ───────────────────────────────────
        self._check_file_safety(tmp)

        # ── 2. Abrir imagen y limpiar EXIF ────────────────────────
        img = self._open_and_strip_exif(tmp)

        # ── 3. Tamaño mínimo ──────────────────────────────────────
        if img.width < 200 or img.height < 200:
            tmp.unlink(missing_ok=True)
            raise ValidationError('La imagen es demasiado pequeña. Mínimo 200×200 px.')

        # ── 4. NSFW check ─────────────────────────────────────────
        self._check_nsfw(str(tmp))

        # ── 5. Verificar rostro ───────────────────────────────────
        if tipo == 'profile':
            faces = self._detect_faces(img)
            if faces == 0:
                tmp.unlink(missing_ok=True)
                raise ValidationError(
                    'No se detectó un rostro en la foto. '
                    'Sube una foto donde se vea claramente tu cara.')

            # ── 6. Verificar género del rostro ────────────────────
            if genero_usuario in ('masculino', 'femenino'):
                self._check_genero(img, genero_usuario)

        # ── 7. Procesar tamaños ───────────────────────────────────
        tipo_norm = tipo if tipo in SIZES else 'profile'
        stem      = Path(filename).stem
        urls      = {}

        for size_name, dimensions in SIZES[tipo_norm]:
            out_dir  = self.storage_root / tipo_norm / size_name
            out_dir.mkdir(parents=True, exist_ok=True)
            out_path = out_dir / f'{stem}.webp'

            resized  = self._resize_crop(img, dimensions)
            # Guardar SIN metadata (save de Pillow no incluye EXIF por defecto en WebP)
            resized.save(str(out_path), format='WEBP',
                         quality=WEBP_QUALITY, method=4)
            urls[size_name] = f'/media/{tipo_norm}/{size_name}/{stem}.webp'

        tmp.unlink(missing_ok=True)
        logger.info(f'[Media] ✅ user={user_id} tipo={tipo_norm}')

        return {
            'urls':     urls,
            'foto_url': urls.get('medium', urls.get('original', '')),
        }

    # ────────────────────────────────────────────────────────────
    # ANTIVIRUS BÁSICO
    # ────────────────────────────────────────────────────────────
    def _check_file_safety(self, path: Path):
        """
        Validaciones de seguridad antes de abrir el archivo:
        1. Tamaño máximo
        2. Magic bytes — verificar que es realmente una imagen
        3. Entropía — detectar archivos comprimidos/cifrados disfrazados
        4. Sin doble extensión sospechosa
        """
        # Tamaño
        size_mb = path.stat().st_size / (1024 * 1024)
        if size_mb > MAX_FILE_MB:
            path.unlink(missing_ok=True)
            raise ValidationError(
                f'Archivo demasiado grande ({size_mb:.1f} MB). Máximo {MAX_FILE_MB} MB.')

        # Archivo vacío
        if path.stat().st_size < 1024:
            path.unlink(missing_ok=True)
            raise ValidationError('El archivo está vacío o corrupto.')

        # Double extension (ej: foto.php.jpg, foto.exe.png)
        nombre = path.name.lower()
        partes = nombre.split('.')
        if len(partes) > 2:
            extensiones_peligrosas = {
                'php', 'php3', 'php4', 'php5', 'phtml',
                'asp', 'aspx', 'jsp', 'cgi', 'pl',
                'exe', 'dll', 'sh', 'bat', 'cmd', 'ps1',
                'py', 'rb', 'js', 'ts',
            }
            for parte in partes[:-1]:
                if parte in extensiones_peligrosas:
                    path.unlink(missing_ok=True)
                    raise ValidationError('Archivo sospechoso rechazado.')

        # Magic bytes
        with open(path, 'rb') as f:
            header = f.read(16)

        es_imagen = False
        for magic, fmt in VALID_MAGIC.items():
            if header[:len(magic)] == magic:
                # Extra check para WebP
                if fmt == 'webp' and header[8:12] != b'WEBP':
                    continue
                es_imagen = True
                break

        if not es_imagen:
            path.unlink(missing_ok=True)
            raise ValidationError(
                'El archivo no es una imagen válida. '
                'Solo se aceptan JPEG, PNG, WebP o GIF.')

        # Entropía — archivos con entropía muy alta pueden ser
        # ejecutables/cifrados disfrazados como imágenes
        entropia = self._calcular_entropia(path)
        if entropia > 7.95:  # Imágenes normales tienen ~6-7.5
            logger.warning(f'[Media] Entropía alta: {entropia:.2f} — {path.name}')
            # No rechazamos, solo logueamos. Algunas imágenes WebP pueden tener
            # entropía alta por la compresión. El magic bytes ya validó el formato.

    def _calcular_entropia(self, path: Path) -> float:
        """Shannon entropy de los primeros 64KB del archivo."""
        try:
            with open(path, 'rb') as f:
                data = f.read(65536)
            if not data:
                return 0.0
            freq  = [0] * 256
            for byte in data:
                freq[byte] += 1
            n = len(data)
            return -sum(
                (c / n) * math.log2(c / n)
                for c in freq if c > 0
            )
        except Exception:
            return 0.0

    # ────────────────────────────────────────────────────────────
    # EXIF — LIMPIAR METADATA
    # ────────────────────────────────────────────────────────────
    def _open_and_strip_exif(self, path: Path) -> Image.Image:
        """
        Abre la imagen, corrige orientación EXIF y elimina TODA la metadata:
        - GPS (ubicación)
        - Datos de cámara / dispositivo
        - Timestamps
        - Miniaturas embebidas
        - Comentarios
        """
        try:
            img = Image.open(path)
            # Corregir orientación usando EXIF antes de borrarlo
            img = ImageOps.exif_transpose(img)
            # Convertir a RGB (elimina cualquier canal alfa + metadata de color)
            img = img.convert('RGB')
            # Crear nueva imagen desde los datos puros — sin metadata
            clean = Image.new('RGB', img.size)
            clean.putdata(list(img.getdata()))
            # Verificar que no tenga info residual
            clean.info = {}
            return clean
        except Exception as exc:
            path.unlink(missing_ok=True)
            raise ValidationError(f'No se pudo abrir la imagen: {exc}')

    # ────────────────────────────────────────────────────────────
    # NSFW
    # ────────────────────────────────────────────────────────────
    def _check_nsfw(self, image_path: str):
        """Detecta contenido NSFW. Si nudenet no está instalado, omite."""
        try:
            from nudenet import NudeDetector
            detector   = NudeDetector()
            detections = detector.detect(image_path) or []
            for det in detections:
                clase = det.get('class', '')
                score = float(det.get('score', 0))
                if clase in NSFW_REJECT and score >= NSFW_THRESHOLD:
                    Path(image_path).unlink(missing_ok=True)
                    raise ValidationError(
                        'Imagen rechazada: contiene contenido inapropiado. '
                        'Solo se permiten fotos de perfil con ropa.')
        except ImportError:
            pass  # nudenet no instalado — modo permisivo
        except ValidationError:
            raise
        except Exception as exc:
            logger.error(f'[Media] NSFW check error: {exc}')

    # ────────────────────────────────────────────────────────────
    # DETECCIÓN DE ROSTRO
    # ────────────────────────────────────────────────────────────
    def _detect_faces(self, img: Image.Image) -> int:
        """
        Detecta cuántos rostros hay en la imagen.
        Usa OpenCV Haar Cascade (rápido, sin GPU).
        Si OpenCV no está disponible, intenta con PIL básico.
        Retorna número de rostros detectados.
        """
        # Intentar con OpenCV (más preciso)
        try:
            import cv2
            import numpy as np

            arr  = np.array(img)
            gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)

            # Cascade frontal + perfil para mayor detección
            cascades = [
                cv2.data.haarcascades + 'haarcascade_frontalface_default.xml',
                cv2.data.haarcascades + 'haarcascade_frontalface_alt2.xml',
                cv2.data.haarcascades + 'haarcascade_profileface.xml',
            ]

            for cascade_path in cascades:
                if not os.path.exists(cascade_path):
                    continue
                cascade = cv2.CascadeClassifier(cascade_path)
                faces   = cascade.detectMultiScale(
                    gray,
                    scaleFactor  = 1.1,
                    minNeighbors = 4,
                    minSize      = (60, 60),
                )
                if len(faces) > 0:
                    logger.info(f'[Media] Rostros detectados: {len(faces)}')
                    return len(faces)

            return 0
        except ImportError:
            logger.warning('[Media] OpenCV no disponible — omitiendo detección de cara')
            return 1  # Sin OpenCV asumimos que hay cara para no bloquear
        except Exception as exc:
            logger.error(f'[Media] Error detección cara: {exc}')
            return 1

    # ────────────────────────────────────────────────────────────
    # VERIFICACIÓN DE GÉNERO
    # ────────────────────────────────────────────────────────────
    def _check_genero(self, img: Image.Image, genero_esperado: str):
        """
        Verifica que el género del rostro detectado coincida con el
        género declarado por el usuario en el registro.

        Si deepface no está instalado, omite la validación.
        genero_esperado: 'masculino' | 'femenino'
        """
        try:
            from deepface import DeepFace
            import numpy as np

            arr = np.array(img)

            resultado = DeepFace.analyze(
                img_path    = arr,
                actions     = ['gender'],
                enforce_detection = False,
                silent      = True,
            )

            # Puede venir como lista o dict
            if isinstance(resultado, list):
                resultado = resultado[0]

            genero_detectado = resultado.get('dominant_gender', '').lower()
            confianza        = resultado.get('gender', {})

            # Mapear a nuestros valores
            es_hombre = genero_detectado in ('man', 'male', 'hombre', 'masculino')
            es_mujer  = genero_detectado in ('woman', 'female', 'mujer', 'femenino')

            logger.info(f'[Media] Género detectado: {genero_detectado} | esperado: {genero_esperado}')

            if genero_esperado == 'masculino' and es_mujer:
                # Verificar confianza — solo rechazar si hay alta certeza
                conf_mujer = confianza.get('Woman', 0) if isinstance(confianza, dict) else 0
                if conf_mujer > 70:
                    raise ValidationError(
                        'La foto no coincide con el género registrado. '
                        'Sube una foto que te muestre claramente a ti.')

            elif genero_esperado == 'femenino' and es_hombre:
                conf_hombre = confianza.get('Man', 0) if isinstance(confianza, dict) else 0
                if conf_hombre > 70:
                    raise ValidationError(
                        'La foto no coincide con el género registrado. '
                        'Sube una foto que te muestre claramente a ti.')

        except ImportError:
            logger.warning('[Media] DeepFace no disponible — omitiendo validación de género')
        except ValidationError:
            raise
        except Exception as exc:
            logger.error(f'[Media] Error verificación género: {exc}')

    # ────────────────────────────────────────────────────────────
    # HELPERS
    # ────────────────────────────────────────────────────────────
    def _resize_crop(self, img: Image.Image, size: tuple) -> Image.Image:
        """Redimensiona con crop centrado."""
        tw, th = size
        iw, ih = img.size
        scale   = max(tw / iw, th / ih)
        nw      = max(int(iw * scale), tw)
        nh      = max(int(ih * scale), th)
        resized = img.resize((nw, nh), Image.LANCZOS)
        left = (nw - tw) // 2
        top  = (nh - th) // 2
        return resized.crop((left, top, left + tw, top + th))
