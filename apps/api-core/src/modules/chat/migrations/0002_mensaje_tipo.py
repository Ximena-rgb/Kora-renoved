from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ('kora_chat', '0001_initial'),
    ]
    operations = [
        migrations.AddField(
            model_name='mensaje',
            name='tipo',
            field=models.CharField(
                choices=[
                    ('mensaje', 'Mensaje normal'),
                    ('ai_icebreaker', 'Icebreaker IA'),
                    ('ai_coach', 'Consejo IA'),
                    ('game_verdad', 'Juego — Verdad'),
                    ('game_reto', 'Juego — Reto'),
                    ('game_quien', 'Juego — ¿Quién?'),
                    ('sistema', 'Sistema'),
                ],
                default='mensaje',
                max_length=20,
            ),
        ),
    ]
