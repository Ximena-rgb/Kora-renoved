from django.db import migrations


FACULTADES_PROGRAMAS = [
    {
        'nombre': 'Facultad de Ingeniería',
        'slug': 'ingenieria',
        'orden': 1,
        'programas': [
            # Tecnologías
            {'nombre': 'Tecnología en Análisis y Desarrollo de Software', 'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Automatización Industrial',         'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Construcción',                      'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Electromecánica',                   'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Electrónica',                       'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Electrónica Industrial',            'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Electricidad',                      'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Gestión de Redes de Computadores',  'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Mantenimiento de Aeronaves',        'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Mecánica Industrial',               'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Sistemas Mecatrónicos',             'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Producción de Alimentos',           'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Regencia de Farmacia',              'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Salud Ocupacional',                 'nivel': 'tecnologo'},
            # Profesionales
            {'nombre': 'Ingeniería Civil',          'nivel': 'profesional'},
            {'nombre': 'Ingeniería de Materiales',  'nivel': 'profesional'},
            {'nombre': 'Ingeniería de Software',    'nivel': 'profesional'},
            {'nombre': 'Ingeniería de Sistemas',    'nivel': 'profesional'},
            {'nombre': 'Ingeniería Eléctrica',      'nivel': 'profesional'},
            {'nombre': 'Ingeniería Electrónica',    'nivel': 'profesional'},
            {'nombre': 'Ingeniería Industrial',     'nivel': 'profesional'},
            {'nombre': 'Ingeniería Mecánica',       'nivel': 'profesional'},
            {'nombre': 'Ingeniería Mecatrónica',    'nivel': 'profesional'},
            {'nombre': 'Ingeniería Metalúrgica',    'nivel': 'profesional'},
            {'nombre': 'Ingeniería Química',        'nivel': 'profesional'},
            # Posgrados
            {'nombre': 'Especialización en Big Data',                                  'nivel': 'especializacion'},
            {'nombre': 'Especialización en Gestión de Activos',                        'nivel': 'especializacion'},
            {'nombre': 'Especialización en Gerencia de Proyectos de Ingeniería',       'nivel': 'especializacion'},
            {'nombre': 'Especialización en Automatización y Control Industrial',       'nivel': 'especializacion'},
            {'nombre': 'Especialización en Seguridad y Salud en el Trabajo',          'nivel': 'especializacion'},
            {'nombre': 'Maestría en Ingeniería',                                       'nivel': 'maestria'},
            {'nombre': 'Maestría en Energía',                                          'nivel': 'maestria'},
            {'nombre': 'Maestría en Gerencia de la Transformación Digital',            'nivel': 'maestria'},
            {'nombre': 'Maestría en Ciencias Computacionales',                         'nivel': 'maestria'},
        ],
    },
    {
        'nombre': 'Facultad de Producción y Diseño',
        'slug': 'produccion-diseno',
        'orden': 2,
        'programas': [
            # Tecnologías
            {'nombre': 'Tecnología en Diseño de Modas',                'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Diseño y Producción Gráfica',    'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Gestión del Diseño Gráfico',     'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Gestión del Diseño Textil y de Moda', 'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Gestión de Empresas de Moda',    'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Gestión Logística',              'nivel': 'tecnologo'},
            {'nombre': 'Tecnología en Producción Industrial',          'nivel': 'tecnologo'},
            # Profesionales
            {'nombre': 'Diseño Industrial',                'nivel': 'profesional'},
            {'nombre': 'Diseño de Comunicación Visual',    'nivel': 'profesional'},
            {'nombre': 'Diseño de Modas',                  'nivel': 'profesional'},
            {'nombre': 'Profesional en Gestión del Diseño','nivel': 'profesional'},
            {'nombre': 'Ingeniería en Logística',          'nivel': 'profesional'},
            {'nombre': 'Ingeniería Industrial',            'nivel': 'profesional'},
            # Posgrados
            {'nombre': 'Especialización en Diseño de Experiencias Digitales', 'nivel': 'especializacion'},
            {'nombre': 'Especialización en Diseño Sostenible',                'nivel': 'especializacion'},
            {'nombre': 'Especialización en Gestión de Proyectos',             'nivel': 'especializacion'},
            {'nombre': 'Maestría en Diseño y Evaluación de Proyectos Regionales', 'nivel': 'maestria'},
        ],
    },
]


def cargar_datos(apps, schema_editor):
    Facultad = apps.get_model('academia', 'Facultad')
    Programa = apps.get_model('academia', 'Programa')
    for i, fac_data in enumerate(FACULTADES_PROGRAMAS):
        fac, _ = Facultad.objects.update_or_create(
            slug=fac_data['slug'],
            defaults={
                'nombre': fac_data['nombre'],
                'orden':  fac_data['orden'],
                'activa': True,
            },
        )
        for j, prog_data in enumerate(fac_data['programas']):
            Programa.objects.update_or_create(
                facultad=fac,
                nombre=prog_data['nombre'],
                defaults={'nivel': prog_data['nivel'], 'activo': True, 'orden': j},
            )


def revertir(apps, schema_editor):
    pass


class Migration(migrations.Migration):

    dependencies = [
        ('academia', '0001_initial'),
    ]

    operations = [
        migrations.RunPython(cargar_datos, revertir),
    ]
