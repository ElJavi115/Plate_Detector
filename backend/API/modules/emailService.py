import sendgrid
from sendgrid.helpers.mail import Mail, Email, To, Content
from .config import SENDGRID_API_KEY, MAIL_FROM_ADDRESS


def send_email(subject, to_email, body):
    sg = sendgrid.SendGridAPIClient(api_key=SENDGRID_API_KEY)

    from_email = Email(MAIL_FROM_ADDRESS)  
    to_email = To(to_email)
    content = Content("text/plain", body)

    mail = Mail(from_email, to_email, subject, content)

    try:
        response = sg.client.mail.send.post(request_body=mail.get())
        print(f"Email enviado a {to_email}: Status {response.status_code}")
        return response
    except Exception as e:
        print(f"Error enviando email: {e}")
        return None


def enviar_correo_reportante(email_reportante, incidencia_id, fecha, hora, descripcion, marca, modelo, placa):
    """Envía correo a la persona que levantó la incidencia (aprobada)"""
    subject = f"Incidencia Aprobada - Reporte #{incidencia_id}"
    
    body = f"""Hola,

Tu reporte de incidencia ha sido aprobado por el administrador.

Detalles de la incidencia:
- ID: #{incidencia_id}
- Fecha: {fecha}
- Hora: {hora}
- Descripción: {descripcion}
- Vehículo reportado: {marca} - {modelo} 
- Placa {placa}

Gracias por contribuir a mantener el orden en las instalaciones.

Saludos,
Sistema de Control Vehicular VAFE"""

    return send_email(subject, email_reportante, body)


def enviar_correo_persona_afectada(nombre, email, numero_incidencias, fecha, hora, descripcion, marca, modelo, placa, incidencia_id):
    """Envía correo a la persona afectada por la incidencia"""
    
    if numero_incidencias < 3:
        subject = f"Notificación de Incidencia #{numero_incidencias} - Advertencia"
        
        body = f"""Estimado/a {nombre},

Se ha registrado una incidencia en tu contra:

Detalles:
- Incidencia número: {numero_incidencias} de 3
- ID: #{incidencia_id}
- Fecha: {fecha}
- Hora: {hora}
- Descripción: {descripcion}
- Vehículo: {marca} - {modelo} 
- Placa {placa}

⚠️ ADVERTENCIA: Actualmente tienes {numero_incidencias} incidencia(s) registrada(s). 
Al llegar a 3 incidencias, tu acceso será bloqueado automáticamente.

Te pedimos tomar las medidas necesarias para evitar futuras infracciones.

Saludos,
Sistema de Control Vehicular VAFE"""
    
    else:
        subject = "ACCESO BLOQUEADO - Tercera Incidencia Registrada"
        
        body = f"""Estimado/a {nombre},

Se ha registrado tu tercera incidencia y tu acceso ha sido BLOQUEADO:

Detalles de la última incidencia:
- ID: #{incidencia_id}
- Fecha: {fecha}
- Descripción: {descripcion}
- Vehículo: {marca} {modelo} - Placa {placa}

🚫 ESTADO: BLOQUEADO

Has acumulado 3 incidencias, por lo que tu acceso a las instalaciones ha sido suspendido.

Para solicitar la reactivación de tu acceso, por favor contacta al administrador.

Saludos,
Sistema de Control Vehicular VAFE"""

    return send_email(subject, email, body)


def enviar_correo_incidencia_rechazada(email_reportante, incidencia_id, fecha, descripcion):
    subject = f"Incidencia Rechazada - Reporte #{incidencia_id}"
    
    body = f"""Hola,

Tu reporte de incidencia ha sido revisado y RECHAZADO por el administrador.

Detalles de la incidencia:
- ID: #{incidencia_id}
- Fecha: {fecha}
- Hora: {hora}
- Descripción: {descripcion}

La incidencia no procede según los criterios de evaluación.

Saludos,
Sistema de Control Vehicular VAFE"""

    return send_email(subject, email_reportante, body)