from .settings import *

# Explicitly use local SQLite for testing so tests NEVER touch Neon
DATABASES = {
    'default': {
        'ENGINE': 'django.db.backends.sqlite3',
        'NAME': BASE_DIR / 'test_db.sqlite3',
    }
}
