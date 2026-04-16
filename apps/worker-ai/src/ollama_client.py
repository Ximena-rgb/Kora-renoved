"""
apps/worker-ai/src/ollama_client.py
=====================================
Cliente para la API de Ollama local.
URL base: https://santiagoherazo.ddns.net:11435

Usa la API compatible con OpenAI (/api/chat o /api/generate).
Modelo por defecto: el primero disponible en /api/tags.
"""

import logging
import os
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry

logger = logging.getLogger('worker-ai')

OLLAMA_BASE_URL = os.getenv('OLLAMA_URL', 'https://santiagoherazo.ddns.net:11435')
OLLAMA_MODEL    = os.getenv('OLLAMA_MODEL', '')  # Se auto-detecta si está vacío
TIMEOUT         = int(os.getenv('OLLAMA_TIMEOUT', '60'))


def _get_session() -> requests.Session:
    session = requests.Session()
    retry   = Retry(total=3, backoff_factor=1, status_forcelist=[502, 503, 504])
    adapter = HTTPAdapter(max_retries=retry)
    session.mount('https://', adapter)
    session.mount('http://', adapter)
    return session


def get_modelo_disponible() -> str:
    """Retorna el primer modelo disponible en el servidor Ollama."""
    global OLLAMA_MODEL
    if OLLAMA_MODEL:
        return OLLAMA_MODEL
    try:
        resp = _get_session().get(
            f'{OLLAMA_BASE_URL}/api/tags', timeout=10, verify=False
        )
        resp.raise_for_status()
        modelos = resp.json().get('models', [])
        if modelos:
            OLLAMA_MODEL = modelos[0]['name']
            logger.info(f'[Ollama] Modelo detectado: {OLLAMA_MODEL}')
            return OLLAMA_MODEL
    except Exception as exc:
        logger.error(f'[Ollama] No se pudo obtener modelos: {exc}')
    return 'llama3'  # fallback


def _llamar_ollama(prompt: str, system: str = '', max_tokens: int = 300) -> str:
    """
    Llama a la API de Ollama y retorna el texto generado.
    Usa /api/generate para compatibilidad máxima.
    """
    modelo = get_modelo_disponible()
    url    = f'{OLLAMA_BASE_URL}/api/generate'

    full_prompt = f"{system}\n\n{prompt}" if system else prompt

    payload = {
        'model':  modelo,
        'prompt': full_prompt,
        'stream': False,
        'options': {
            'temperature':  0.85,
            'top_p':        0.92,
            'num_predict':  max_tokens,
        },
    }

    try:
        resp = _get_session().post(url, json=payload, timeout=TIMEOUT, verify=False)
        resp.raise_for_status()
        return resp.json().get('response', '').strip()
    except requests.exceptions.Timeout:
        logger.error(f'[Ollama] Timeout después de {TIMEOUT}s')
        raise
    except Exception as exc:
        logger.error(f'[Ollama] Error: {exc}')
        raise


# ── Funciones específicas de Kora ────────────────────────────────

def generar_icebreaker(contexto: dict) -> str:
    """
    Genera un mensaje de apertura para iniciar una conversación entre dos matches.
    Se inyecta como primer mensaje en el chat al hacer match de pareja.
    """
    intereses_comunes = list(
        set(contexto.get('intereses_mios', [])) &
        set(contexto.get('intereses_otro', []))
    )
    intereses_str = ', '.join(intereses_comunes) if intereses_comunes else 'temas universitarios'
    nombre_otro   = contexto.get('nombre_otro', 'esta persona')
    carrera_mia   = contexto.get('carrera_mia', 'universitario/a')
    carrera_otro  = contexto.get('carrera_otro', 'universitario/a')

    system = (
        'Eres el Asistente del Amor de Kora, una app universitaria colombiana. '
        'Tu misión es generar mensajes de apertura auténticos, creativos y naturales '
        'para iniciar conversaciones entre estudiantes que acaban de hacer match. '
        'Tono: casual, cálido, universitario colombiano. NUNCA uses frases genéricas como "Hola, vi tu perfil".'
    )

    prompt = (
        f'Dos estudiantes acaban de hacer match en Kora.\n\n'
        f'Información:\n'
        f'- Intereses en común: {intereses_str}\n'
        f'- Mi carrera: {carrera_mia}\n'
        f'- Carrera del match: {carrera_otro}\n\n'
        f'Genera UN solo mensaje de apertura creativo (máx 2 oraciones). '
        f'Debe mencionar algo de sus intereses en común. '
        f'Máximo 1 emoji. Solo responde con el mensaje, sin explicaciones.'
    )

    try:
        resultado = _llamar_ollama(prompt, system=system, max_tokens=120)
        logger.info(f'[Ollama] Icebreaker generado: {resultado[:60]}...')
        return resultado
    except Exception:
        # Fallback sin IA
        if intereses_comunes:
            return f'Hola! Vi que también te gusta {intereses_comunes[0]}, ¿qué tan metido/a estás en eso? 😊'
        return f'Qué onda! Dos estudiantes de {carrera_mia} y {carrera_otro} en el mismo campus... esto es para contarlo 😄'


def generar_consejo_coach(contexto: dict) -> str:
    """Consejo de Date Coach para el usuario."""
    intereses_comunes = list(
        set(contexto.get('intereses_mios', [])) &
        set(contexto.get('intereses_otro', []))
    )
    intereses_str = ', '.join(intereses_comunes) if intereses_comunes else 'varios temas'
    pregunta      = contexto.get('pregunta', '¿Cómo puedo conectar mejor?')

    system = (
        'Eres un Date Coach experto en relaciones universitarias en Colombia. '
        'Das consejos prácticos, directos y con buen humor. '
        'Tono casual, empático, universitario colombiano.'
    )

    prompt = (
        f'Pregunta del usuario: {pregunta}\n\n'
        f'Contexto del match:\n'
        f'- Intereses en común: {intereses_str}\n'
        f'- Carrera del usuario: {contexto.get("carrera_mia", "no especificada")}\n'
        f'- Carrera del match: {contexto.get("carrera_otro", "no especificada")}\n\n'
        f'Da un consejo práctico en máximo 3 oraciones. Solo responde con el consejo.'
    )

    try:
        return _llamar_ollama(prompt, system=system, max_tokens=200)
    except Exception:
        return 'Propone algo relacionado con sus intereses en común. Lo auténtico siempre funciona mejor que los scripts perfectos.'


def generar_verdad_o_reto(tipo: str, tema: str = '') -> dict:
    """
    Genera una pregunta (verdad) o un reto para el modo desparche.
    tipo: 'verdad' | 'reto'
    """
    system = (
        'Eres el animador del modo Desparche de Kora, una app universitaria colombiana. '
        'Generas preguntas y retos divertidos, creativos y apropiados para jóvenes universitarios. '
        'Nada obsceno ni ofensivo. Tono juguetón y universitario.'
    )

    if tipo == 'verdad':
        prompt = (
            f'Genera UNA pregunta de "Verdad" creativa y divertida para universitarios colombianos. '
            f'{f"Tema sugerido: {tema}." if tema else ""} '
            f'La pregunta debe ser interesante y reveladora pero no ofensiva. '
            f'Solo responde con la pregunta.'
        )
    else:
        prompt = (
            f'Genera UN reto creativo y divertido para universitarios colombianos. '
            f'{f"Tema sugerido: {tema}." if tema else ""} '
            f'El reto debe ser factible y divertido pero no ofensivo ni peligroso. '
            f'Solo responde con el reto.'
        )

    try:
        contenido = _llamar_ollama(prompt, system=system, max_tokens=100)
        return {'tipo': tipo, 'contenido': contenido}
    except Exception:
        defaults = {
            'verdad': '¿Cuál ha sido tu momento más vergonzoso en la universidad?',
            'reto':   'Imita a tu profesor favorito por 30 segundos.',
        }
        return {'tipo': tipo, 'contenido': defaults.get(tipo, '¿Quién es más probable?')}


def generar_quien_es_mas_probable(tema: str = '') -> str:
    """Genera una pregunta de '¿Quién es más probable que...?'"""
    system = 'Eres animador del juego "¿Quién es más probable?" en Kora. Preguntas divertidas para universitarios.'
    prompt = (
        f'Genera UNA pregunta de "¿Quién es más probable que...?" '
        f'divertida y apropiada para universitarios. '
        f'{f"Tema: {tema}." if tema else ""} '
        f'Solo responde con la pregunta, comenzando con "¿Quién es más probable que..."'
    )
    try:
        return _llamar_ollama(prompt, system=system, max_tokens=80)
    except Exception:
        return '¿Quién es más probable que se quede dormido en clase?'
