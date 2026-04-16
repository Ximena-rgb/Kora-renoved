import logging
import os

logger = logging.getLogger('worker-ai')

GEMINI_API_KEY = os.getenv('GEMINI_API_KEY', '')
GEMINI_MODEL   = 'gemini-1.5-flash'


def _get_model():
    import google.generativeai as genai
    genai.configure(api_key=GEMINI_API_KEY)
    return genai.GenerativeModel(
        model_name=GEMINI_MODEL,
        generation_config={
            'temperature':       0.85,
            'top_p':             0.95,
            'max_output_tokens': 300,
        },
    )


def generar_icebreaker(contexto: dict) -> str:
    intereses_comunes = list(
        set(contexto.get('intereses_mios', [])) &
        set(contexto.get('intereses_otro', []))
    )
    intereses_str = ', '.join(intereses_comunes) if intereses_comunes else 'temas universitarios'

    prompt = (
        f'Eres un asistente para una app de citas universitarias en Colombia.\n\n'
        f'Genera UN solo mensaje de apertura creativo para iniciar una conversacion entre dos estudiantes.\n\n'
        f'Intereses en comun: {intereses_str}\n'
        f'Mi carrera: {contexto.get("carrera_mia", "universitario")}\n'
        f'Carrera del otro: {contexto.get("carrera_otro", "universitario")}\n\n'
        f'Reglas: Max 2 oraciones, tono casual colombiano, menciona un interes comun, max 1 emoji.\n'
        f'Solo responde con el mensaje.'
    )
    try:
        return _get_model().generate_content(prompt).text.strip()
    except Exception as exc:
        logger.error(f'[Gemini] Error icebreaker: {exc}')
        if intereses_comunes:
            return f'Vi que tambien te interesa {intereses_comunes[0]}, que tan metido estas en eso?'
        return f'Dos estudiantes de {contexto.get("carrera_mia", "la u")} en el mismo campus... interesante.'


def generar_consejo_coach(contexto: dict) -> str:
    intereses_comunes = list(
        set(contexto.get('intereses_mios', [])) &
        set(contexto.get('intereses_otro', []))
    )
    intereses_str = ', '.join(intereses_comunes) if intereses_comunes else 'varios temas'

    prompt = (
        f'Eres un Date Coach para estudiantes universitarios en Colombia.\n\n'
        f'Pregunta: {contexto.get("pregunta", "Como puedo conectar mejor?")}\n\n'
        f'Contexto del match:\n'
        f'- Intereses en comun: {intereses_str}\n'
        f'- Mi carrera: {contexto.get("carrera_mia", "universitario")}\n'
        f'- Carrera del match: {contexto.get("carrera_otro", "universitario")}\n\n'
        f'Da un consejo practico en max 3 oraciones. Tono casual universitario colombiano.\n'
        f'Solo responde con el consejo.'
    )
    try:
        return _get_model().generate_content(prompt).text.strip()
    except Exception as exc:
        logger.error(f'[Gemini] Error coach: {exc}')
        return 'Propone algo relacionado con sus intereses en comun. Lo natural siempre funciona mejor.'
