from django.db import migrations, models
import django.db.models.deletion


class Migration(migrations.Migration):

    initial = True

    dependencies = []

    operations = [
        migrations.CreateModel(
            name='Facultad',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('nombre', models.CharField(max_length=200, unique=True)),
                ('slug', models.SlugField(max_length=100, unique=True)),
                ('activa', models.BooleanField(default=True)),
                ('orden', models.PositiveSmallIntegerField(default=0)),
            ],
            options={'db_table': 'academia_facultades', 'ordering': ['orden', 'nombre'], 'verbose_name': 'Facultad', 'verbose_name_plural': 'Facultades', 'app_label': 'academia'},
        ),
        migrations.CreateModel(
            name='Programa',
            fields=[
                ('id', models.BigAutoField(auto_created=True, primary_key=True, serialize=False, verbose_name='ID')),
                ('nombre', models.CharField(max_length=200)),
                ('nivel', models.CharField(choices=[('tecnico', 'Técnico Profesional'), ('tecnologo', 'Tecnología'), ('profesional', 'Profesional Universitario'), ('especializacion', 'Especialización'), ('maestria', 'Maestría')], default='profesional', max_length=20)),
                ('activo', models.BooleanField(default=True)),
                ('orden', models.PositiveSmallIntegerField(default=0)),
                ('facultad', models.ForeignKey(on_delete=django.db.models.deletion.CASCADE, related_name='programas', to='academia.facultad')),
            ],
            options={'db_table': 'academia_programas', 'ordering': ['facultad__orden', 'orden', 'nombre'], 'verbose_name': 'Programa', 'verbose_name_plural': 'Programas', 'app_label': 'academia'},
        ),
        migrations.AlterUniqueTogether(
            name='programa',
            unique_together={('facultad', 'nombre')},
        ),
    ]
