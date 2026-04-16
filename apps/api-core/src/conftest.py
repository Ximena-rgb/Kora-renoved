import django
import os

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'config.settings')

import pytest
from django.contrib.auth import get_user_model


@pytest.fixture
def usuario_google(db):
    User = get_user_model()
    return User.objects.create_user_from_google(
        email        = 'juan.perez@unal.edu.co',
        firebase_uid = 'google-uid-abc123',
        nombre       = 'Juan Pérez',
        foto_url     = 'https://lh3.googleusercontent.com/test.jpg',
    )
