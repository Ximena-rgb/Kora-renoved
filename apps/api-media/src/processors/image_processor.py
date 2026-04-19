"""
processors/image_processor.py
================================
Pipeline de validación y procesamiento de fotos de perfil para Kora.

Orden de validaciones (fail-fast — rechaza y elimina en el primer fallo):
  1. Seguridad del archivo (magic bytes, tamaño, extensión)
  2. Apertura y limpieza de EXIF
  3. Tamaño mínimo
  4. NSFW — desnudez explícita (nudenet)
  5. Detección de persona (obligatorio: debe haber una cara visible)
  6. Coincidencia de sexo biológico (deepface)
       · hombre   → la foto DEBE ser de un hombre
       · mujer    → la foto DEBE ser de una mujer
       · otro     → se acepta hombre o mujer (solo validar que hay cara)
  7. Resize + WebP sin metadata
"""

import logging
import math
import os
from io import BytesIO
from pathlib import Path

from PIL import Image, ImageFilter, ImageOps, ImageStat

logger = logging.getLogger(__name__)

MAX_FILE_MB    = 15
WEBP_QUALITY   = 85

# Umbral de confianza para género: solo rechaza si deepface está MUY seguro
GENDER_CONF_THRESHOLD = 65   # % de confianza mínima para rechazar

# Clases nudenet que se rechazan SIEMPRE (desnudez explícita)
NSFW_REJECT_EXPLICIT = {
    'FEMALE_GENITALIA_EXPOSED',
    'MALE_GENITALIA_EXPOSED',
    'FEMALE_BREAST_EXPOSED',
    'ANUS_EXPOSED',
    'SEXUAL_ACTIVITY',
    'BUTTOCKS_EXPOSED',
}

# Clases que se rechazan si hay muy alta confianza (semi-desnudez extrema)
NSFW_REJECT_HIGH_CONF = {
    'MALE_GENITALIA_COVERED',   # boxer / ropa interior masculina
    'FEMALE_GENITALIA_COVERED', # ropa interior femenina
}
NSFW_HIGH_CONF_THRESHOLD = 0.80  # 80% confianza

# General NSFW threshold
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

VALID_MAGIC = {
    b'\xff\xd8\xff': 'jpeg',
    b'\x89PNG':      'png',
    b'RIFF':         'webp',
    b'GIF8':         'gif',
    b'BM':           'bmp',
}


class ValidationError(ValueError):
    """Error de validación — la foto no cumple los requisitos."""
    pass


class ImageProcessor:

    def __init__(self, storage_root: str):
        self.storage_root = Path(storage_root)

    def process(self, tmp_path: str, user_id: int, tipo: str, filename: str,
                sexo_biologico: str = '', genero_usuario: str = '') -> dict:
        """
        Procesa y valida una imagen de perfil.

        sexo_biologico: 'hombre' | 'mujer' | '' (vacío o 'intersexual' = sin restricción binaria)
        genero_usuario: campo legacy, se usa como fallback si sexo_biologico está vacío

        Retorna: { 'urls': {...}, 'foto_url': '...' }
        Lanza ValidationError si no pasa alguna validación.
        """
        tmp = Path(tmp_path)
        if not tmp.exists():
            raise FileNotFoundError(f'Archivo no encontrado: {tmp_path}')

        # Normalizar sexo: usar sexo_biologico primero, genero_usuario como fallback
        sexo = self._normalizar_sexo(sexo_biologico or genero_usuario)

        # ── 1. Seguridad del archivo ──────────────────────────────
        self._check_file_safety(tmp)

        # ── 2. Abrir y limpiar EXIF ───────────────────────────────
        img = self._open_and_strip_exif(tmp)

        # ── 3. Tamaño mínimo ──────────────────────────────────────
        if img.width < 200 or img.height < 200:
            tmp.unlink(missing_ok=True)
            raise ValidationError(
                'La imagen es demasiado pequeña. Mínimo 200×200 px.')

        # ── 4. NSFW — rechazar desnudez explícita ─────────────────
        if tipo == 'profile':
            self._check_nsfw(str(tmp))

        # ── 5. Verificar que hay UNA PERSONA en la foto ───────────
        # Para perfiles siempre es obligatorio.
        if tipo == 'profile':
            tiene_cara = self._detectar_persona(img)
            if not tiene_cara:
                tmp.unlink(missing_ok=True)
                raise ValidationError(
                    'No se detectó una persona en la foto. '
                    'Sube una foto donde se vea claramente tu cara. '
                    'No se aceptan paisajes, logos ni imágenes sin personas.')

            # ── 6. Verificar sexo biológico ───────────────────────
            # Solo para hombre/mujer. No-binario/intersexual: solo cara.
            if sexo in ('hombre', 'mujer'):
                self._verificar_sexo(img, sexo)

        # ── 7. Procesar tamaños y guardar ─────────────────────────
        tipo_norm = tipo if tipo in SIZES else 'profile'
        stem      = Path(filename).stem
        urls      = {}

        for size_name, dimensions in SIZES[tipo_norm]:
            out_dir  = self.storage_root / tipo_norm / size_name
            out_dir.mkdir(parents=True, exist_ok=True)
            out_path = out_dir / f'{stem}.webp'
            resized  = self._resize_crop(img, dimensions)
            resized.save(str(out_path), format='WEBP',
                         quality=WEBP_QUALITY, method=4)
            urls[size_name] = f'/media/{tipo_norm}/{size_name}/{stem}.webp'

        tmp.unlink(missing_ok=True)
        logger.info(f'[Media] ✅ user={user_id} tipo={tipo_norm} sexo={sexo}')

        return {
            'urls':     urls,
            'foto_url': urls.get('medium', urls.get('original', '')),
        }

    # ─────────────────────────────────────────────────────────────
    # NORMALIZACIÓN DE SEXO
    # ─────────────────────────────────────────────────────────────
    def _normalizar_sexo(self, valor: str) -> str:
        """
        Mapea cualquier valor de sexo/género a: 'hombre', 'mujer', o 'otro'.
        'otro' = no aplica validación binaria (solo cara).
        """
        v = (valor or '').lower().strip()

        masculino = {
            'hombre', 'masculino', 'male', 'man',
            'hombre_cis', 'hombre_trans', 'hombre_intersex',
            'transmasculino',
        }
        femenino = {
            'mujer', 'femenino', 'female', 'woman',
            'mujer_cis', 'mujer_trans', 'mujer_intersex',
            'transfemenino',
        }

        if v in masculino:
            return 'hombre'
        if v in femenino:
            return 'mujer'
        return 'otro'  # no-binario, intersexual, prefiero_no_decir, vacío

    # ─────────────────────────────────────────────────────────────
    # SEGURIDAD DEL ARCHIVO
    # ─────────────────────────────────────────────────────────────
    def _check_file_safety(self, path: Path):
        size_mb = path.stat().st_size / (1024 * 1024)
        if size_mb > MAX_FILE_MB:
            path.unlink(missing_ok=True)
            raise ValidationError(
                f'Archivo demasiado grande ({size_mb:.1f} MB). Máximo {MAX_FILE_MB} MB.')

        if path.stat().st_size < 1024:
            path.unlink(missing_ok=True)
            raise ValidationError('El archivo está vacío o corrupto.')

        nombre = path.name.lower()
        partes = nombre.split('.')
        peligrosas = {
            'php', 'php3', 'php4', 'php5', 'phtml', 'asp', 'aspx',
            'jsp', 'cgi', 'pl', 'exe', 'dll', 'sh', 'bat', 'cmd',
            'ps1', 'py', 'rb', 'js', 'ts',
        }
        if len(partes) > 2:
            for parte in partes[:-1]:
                if parte in peligrosas:
                    path.unlink(missing_ok=True)
                    raise ValidationError('Archivo sospechoso rechazado.')

        with open(path, 'rb') as f:
            header = f.read(16)

        es_imagen = False
        for magic, fmt in VALID_MAGIC.items():
            if header[:len(magic)] == magic:
                if fmt == 'webp' and header[8:12] != b'WEBP':
                    continue
                es_imagen = True
                break

        if not es_imagen:
            path.unlink(missing_ok=True)
            raise ValidationError(
                'El archivo no es una imagen válida. '
                'Solo se aceptan JPEG, PNG, WebP o GIF.')

    # ─────────────────────────────────────────────────────────────
    # EXIF
    # ─────────────────────────────────────────────────────────────
    def _open_and_strip_exif(self, path: Path) -> Image.Image:
        try:
            img   = Image.open(path)
            img   = ImageOps.exif_transpose(img)
            img   = img.convert('RGB')
            clean = Image.new('RGB', img.size)
            clean.putdata(list(img.getdata()))
            clean.info = {}
            return clean
        except Exception as exc:
            path.unlink(missing_ok=True)
            raise ValidationError(f'No se pudo abrir la imagen: {exc}')

    # ─────────────────────────────────────────────────────────────
    # NSFW
    # ─────────────────────────────────────────────────────────────
    def _check_nsfw(self, image_path: str):
        """
        Detecta contenido inapropiado con nudenet.
        Reglas:
          - Desnudez explícita (genitales, senos, etc.) → rechazar siempre
          - Ropa interior / boxer con alta confianza → rechazar
          - Traje de baño, torso sin camisa → PERMITIDO (no están en las listas)
        """
        try:
            from nudenet import NudeDetector
            detector   = NudeDetector()
            detections = detector.detect(image_path) or []

            for det in detections:
                clase  = det.get('class', '')
                score  = float(det.get('score', 0))

                # Desnudez explícita — umbral bajo
                if clase in NSFW_REJECT_EXPLICIT and score >= NSFW_THRESHOLD:
                    Path(image_path).unlink(missing_ok=True)
                    raise ValidationError(
                        'Imagen rechazada: contiene contenido inapropiado. '
                        'Solo se permiten fotos con ropa. '
                        'El traje de baño y torso sin camiseta son permitidos, '
                        'pero la ropa interior o menos no está permitida.')

                # Ropa interior con muy alta confianza → rechazar
                if clase in NSFW_REJECT_HIGH_CONF and score >= NSFW_HIGH_CONF_THRESHOLD:
                    Path(image_path).unlink(missing_ok=True)
                    raise ValidationError(
                        'Imagen rechazada: la ropa interior no está permitida. '
                        'Sube una foto con ropa de calle, traje de baño o similar.')

        except ImportError:
            logger.warning('[Media] nudenet no instalado — NSFW omitido')
        except ValidationError:
            raise
        except Exception as exc:
            logger.error(f'[Media] Error NSFW: {exc}')

    # ─────────────────────────────────────────────────────────────
    # DETECCIÓN DE PERSONA (obligatorio)
    # ─────────────────────────────────────────────────────────────
    def _detectar_persona(self, img: Image.Image) -> bool:
        """
        Verifica que haya al menos una persona (cara) en la imagen.
        Estrategia multi-capa:
          1. OpenCV Haar cascades (rápido, robusto)
          2. DeepFace como segunda opinión si OpenCV no detecta
          3. Fallback Pillow (análisis de piel) como último recurso

        Un paisaje, logo, objeto o animal NO tiene cara → retorna False.
        """
        # Intentar con OpenCV primero
        opencv_result = self._detectar_con_opencv(img)
        if opencv_result is True:
            return True
        if opencv_result is False:
            # OpenCV corrió bien pero NO encontró cara → segunda opinión con DeepFace
            deepface_result = self._detectar_con_deepface(img)
            if deepface_result is not None:
                return deepface_result
            # Si DeepFace tampoco encontró → no hay persona
            return False

        # opencv_result is None → OpenCV no disponible → probar DeepFace
        deepface_result = self._detectar_con_deepface(img)
        if deepface_result is not None:
            return deepface_result

        # Último recurso: análisis de piel con Pillow
        return self._detectar_con_pillow(img)

    def _detectar_con_opencv(self, img: Image.Image):
        """
        Retorna: True (cara encontrada), False (corrió OK pero sin cara), None (no disponible).
        """
        try:
            import cv2
            import numpy as np

            arr  = np.array(img)
            gray = cv2.cvtColor(arr, cv2.COLOR_RGB2GRAY)
            gray_eq = cv2.equalizeHist(gray)

            cascades = [
                cv2.data.haarcascades + 'haarcascade_frontalface_default.xml',
                cv2.data.haarcascades + 'haarcascade_frontalface_alt.xml',
                cv2.data.haarcascades + 'haarcascade_frontalface_alt2.xml',
                cv2.data.haarcascades + 'haarcascade_profileface.xml',
            ]
            param_sets = [
                {'scaleFactor': 1.05, 'minNeighbors': 3, 'minSize': (30, 30)},
                {'scaleFactor': 1.10, 'minNeighbors': 4, 'minSize': (50, 50)},
                {'scaleFactor': 1.15, 'minNeighbors': 5, 'minSize': (70, 70)},
            ]

            for cascade_path in cascades:
                if not os.path.exists(cascade_path):
                    continue
                cascade = cv2.CascadeClassifier(cascade_path)
                if cascade.empty():
                    continue
                for src in (gray, gray_eq):
                    for params in param_sets:
                        faces = cascade.detectMultiScale(src, **params)
                        if len(faces) > 0:
                            logger.info(f'[Media] OpenCV: {len(faces)} cara(s)')
                            return True

            logger.info('[Media] OpenCV: sin cara detectada')
            return False  # Corrió bien pero no encontró

        except ImportError:
            return None  # No disponible
        except Exception as exc:
            logger.error(f'[Media] OpenCV error: {exc}')
            return None

    def _detectar_con_deepface(self, img: Image.Image):
        """
        Retorna: True (persona detectada), False (no hay persona), None (no disponible/error).
        """
        try:
            from deepface import DeepFace
            import numpy as np

            arr = np.array(img)
            resultado = DeepFace.analyze(
                img_path=arr,
                actions=['gender'],
                enforce_detection=True,   # True = falla si no hay cara
                silent=True,
            )
            # Si llegó aquí sin excepción → hay una cara
            logger.info('[Media] DeepFace: cara encontrada')
            return True

        except Exception as exc:
            msg = str(exc).lower()
            if 'face' in msg or 'detect' in msg or 'no face' in msg:
                logger.info('[Media] DeepFace: sin cara')
                return False
            logger.warning(f'[Media] DeepFace indisponible: {exc}')
            return None  # Error técnico → no podemos decidir

    def _detectar_con_pillow(self, img: Image.Image) -> bool:
        """
        Fallback final: análisis de tono de piel y bordes.
        Solo acepta si hay suficiente evidencia de piel humana.
        Umbral más estricto que el original para no aceptar paisajes.
        """
        try:
            w, h   = img.size
            margin = 0.15
            crop   = img.crop((
                int(w * margin), int(h * margin),
                int(w * (1 - margin)), int(h * (1 - margin)),
            ))

            rgb_data = list(crop.getdata())
            total    = len(rgb_data)
            skin_px  = 0
            for r, g, b in rgb_data:
                # Tonos de piel Fitzpatrick I-VI
                if (r > 60 and g > 40 and b > 20 and
                        r > g > b and
                        r - g > 15 and
                        abs(r - g) < 100):
                    skin_px += 1
            skin_ratio = skin_px / total if total > 0 else 0

            gray_crop = crop.convert('L')
            edges     = gray_crop.filter(ImageFilter.FIND_EDGES)
            edge_mean = ImageStat.Stat(edges).mean[0]

            logger.info(f'[Media] Pillow: skin={skin_ratio:.2f} edges={edge_mean:.1f}')

            # Umbral ESTRICTO: requiere más piel Y más bordes
            if skin_ratio >= 0.12 and edge_mean >= 10.0:
                return True
            if skin_ratio >= 0.30:  # selfie muy cercana
                return True

            return False

        except Exception as exc:
            logger.error(f'[Media] Pillow fallback error: {exc}')
            return False  # En caso de error → rechazar (más seguro)

    # ─────────────────────────────────────────────────────────────
    # VERIFICACIÓN DE SEXO BIOLÓGICO
    # ─────────────────────────────────────────────────────────────
    def _verificar_sexo(self, img: Image.Image, sexo_esperado: str):
        """
        Verifica que el género del rostro coincida con el sexo biológico declarado.
        Solo para 'hombre' o 'mujer'. No-binario/otro → no se llama.

        Usa DeepFace. Si no está disponible → modo permisivo con advertencia.
        """
        try:
            from deepface import DeepFace
            import numpy as np

            arr = np.array(img)
            resultado = DeepFace.analyze(
                img_path=arr,
                actions=['gender'],
                enforce_detection=False,
                silent=True,
            )

            if isinstance(resultado, list):
                resultado = resultado[0]

            genero_det = resultado.get('dominant_gender', '').lower()
            confianzas = resultado.get('gender', {})

            es_hombre = genero_det in ('man', 'male')
            es_mujer  = genero_det in ('woman', 'female')

            logger.info(
                f'[Media] Género detectado: {genero_det} | '
                f'esperado: {sexo_esperado} | confianzas: {confianzas}'
            )

            if sexo_esperado == 'hombre':
                if es_mujer:
                    conf = confianzas.get('Woman', 0) if isinstance(confianzas, dict) else 0
                    if conf >= GENDER_CONF_THRESHOLD:
                        raise ValidationError(
                            f'La foto no corresponde a tu sexo registrado (hombre). '
                            f'La imagen fue identificada como mujer con {conf:.0f}% de confianza. '
                            f'Sube una foto tuya.')
                elif not es_hombre and not es_mujer:
                    # DeepFace no pudo determinar → no rechazamos
                    logger.info('[Media] Género indeterminado → permitido')

            elif sexo_esperado == 'mujer':
                if es_hombre:
                    conf = confianzas.get('Man', 0) if isinstance(confianzas, dict) else 0
                    if conf >= GENDER_CONF_THRESHOLD:
                        raise ValidationError(
                            f'La foto no corresponde a tu sexo registrado (mujer). '
                            f'La imagen fue identificada como hombre con {conf:.0f}% de confianza. '
                            f'Sube una foto tuya.')

        except ImportError:
            logger.warning('[Media] DeepFace no instalado — verificación de sexo omitida')
        except ValidationError:
            raise
        except Exception as exc:
            logger.error(f'[Media] Error verificación sexo: {exc}')
            # No rechazar por error técnico de DeepFace

    # ─────────────────────────────────────────────────────────────
    # HELPERS
    # ─────────────────────────────────────────────────────────────
    def _resize_crop(self, img: Image.Image, size: tuple) -> Image.Image:
        tw, th = size
        iw, ih = img.size
        scale   = max(tw / iw, th / ih)
        nw      = max(int(iw * scale), tw)
        nh      = max(int(ih * scale), th)
        resized = img.resize((nw, nh), Image.LANCZOS)
        left    = (nw - tw) // 2
        top     = (nh - th) // 2
        return resized.crop((left, top, left + tw, top + th))
