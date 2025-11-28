from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import joinedload

from .config import Base, engine, SessionLocal
from .models import Auto, Incidencia, Perfil, Persona
from .schemas import AutoCreate, AutoRead, IncidenciaCreate, IncidenciaRead, PersonaCreate, PersonaRead
from .emailService import enviar_correo_persona_afectada, enviar_correo_reportante, enviar_correo_incidencia_rechazada

from paddleocr import PaddleOCR
import os
import numpy as np
import cv2
import tempfile
import json
from pathlib import Path

app = FastAPI(title="API Placas", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

ocr: PaddleOCR | None = None


@app.on_event("startup")
def startup():
    global ocr
    Base.metadata.create_all(bind=engine)
    cargar_perfiles_iniciales()
    cargar_datos_iniciales()

    ocr = PaddleOCR(
        lang="en",
        use_doc_orientation_classify=False,
        use_doc_unwarping=False,
        use_textline_orientation=False,
    )


def cargar_perfiles_iniciales():
    db = SessionLocal()
    try:
        if db.query(Perfil).first():
            print("Perfiles ya cargados.")
            return
        
        perfil_usuario = Perfil(
            nombre="Usuario", 
            descripcion="Usuario normal con acceso limitado")
        perfil_admin = Perfil(
            nombre="Administrador", 
            descripcion="Usuario con acceso completo")
            
        db.add(perfil_usuario)
        db.add(perfil_admin)
        db.commit()
        print("Perfiles iniciales cargados exitosamente.")
    finally:
        db.close()


def cargar_datos_iniciales():
    db = SessionLocal()
    try:
        if db.query(Persona).first():
            print("Datos ya cargados.")
            return

        datos = [
            {
                "persona": {
                    "nombre": "Javier Uribe Armenta",
                    "edad": 22,
                    "numeroControl": "21170497",
                    "correo": "javier.ua01@gmail.com",
                    "estatus": "Autorizado",
                    "noIncidencias": 0,
                    "perfil_id": 2
                },
                "autos": [
                    {
                        "placa": "60-UW-5F",
                        "marca": "Chevrolet",
                        "modelo": "Spark",
                        "color": "Plateado",
                    },
                    {
                        "placa": "ABC-123-A",
                        "marca": "Nissan",
                        "modelo": "Versa",
                        "color": "Gris",
                    },
                ],
            },
            {
                "persona": {
                    "nombre": "Ana",
                    "edad": 28,
                    "numeroControl": "654321",
                    "correo": "ana@example.com",
                    "estatus": "Autorizado",
                    "noIncidencias": 0,
                    "perfil_id": 1
                },
                "autos": [ 
                    {
                        "placa": "NA-86-83",
                        "marca": "Toyota",
                        "modelo": "Corolla",
                        "color": "Azul",
                    },
                ],
            },
            {
                "persona": {
                    "nombre": "Carlos",
                    "edad": 40,
                    "numeroControl": "112233",
                    "correo": "carlos@example.com",
                    "estatus": "Autorizado",
                    "noIncidencias": 0,
                    "perfil_id": 1
                },
                "autos": [
                    {
                        "placa": "JCZ-263-A",
                        "marca": "Honda",
                        "modelo": "Civic",
                        "color": "Negro",
                    },
                ],
            },
        ]

        for item in datos:
            persona = Persona(**item["persona"])
            db.add(persona)
            db.commit()
            db.refresh(persona)

            for auto_data in item.get("autos", []):
                auto = Auto(**auto_data, persona_id=persona.id)
                db.add(auto)

            db.commit()
    finally:
        db.close()


# ========== Helpers ==========

def normalizar_placa(texto: str) -> str:
    texto = texto.upper().strip()
    texto = texto.replace(" ", "")
    return texto

def buscar_en_bd_por_placa_norm(placa_norm: str):
    db = SessionLocal()
    try:
        consulta = db.query(Auto).join(Persona).filter(Auto.placa == placa_norm).first()

        if not consulta:
            return None

        respuesta = {
            "persona": {
                "id": consulta.persona.id,
                "nombre": consulta.persona.nombre,
                "edad": consulta.persona.edad,
                "numeroControl": consulta.persona.numeroControl,
                "correo": consulta.persona.correo,
                "estatus": consulta.persona.estatus,
                "noIncidencias": consulta.persona.noIncidencias,
            },
            "auto": {
                "id": consulta.id,
                "placa": consulta.placa,
                "marca": consulta.marca,
                "modelo": consulta.modelo,
                "color": consulta.color,
            },
        }
        return respuesta
    finally:
        db.close()


def respuesta_persona_auto(persona: Persona, auto: Auto | None):
    persona_dict = {
        "id": persona.id,
        "nombre": persona.nombre,
        "edad": persona.edad,
        "numeroControl": persona.numeroControl,
        "correo": persona.correo,
        "estatus": persona.estatus,
        "noIncidencias": persona.noIncidencias,
    }

    auto_dict = None
    if auto is not None:
        auto_dict = {
            "id": auto.id,
            "placa": auto.placa,
            "marca": auto.marca,
            "modelo": auto.modelo,
            "color": auto.color,
        }

    return {
        "persona": persona_dict,
        "auto": auto_dict,
    }


def respuesta_incidencia(incidencia: Incidencia):
    incidencia_dict = {
        "id": incidencia.id,
        "descripcion": incidencia.descripcion,
        "fecha": incidencia.fecha,
        "hora": incidencia.hora or "",
        "imagenes": json.loads(incidencia.imagenes) if incidencia.imagenes else [],
        "estatus": incidencia.estatus,
        "latitud": incidencia.latitud or "0", 
        "longitud": incidencia.longitud or "0"  
    }
    
    persona_afectada_dict = None 
    if incidencia.persona_afectada is not None:
        persona_afectada_dict = {
            "id": incidencia.persona_afectada.id,
            "nombre": incidencia.persona_afectada.nombre,
            "edad": incidencia.persona_afectada.edad,
            "numeroControl": incidencia.persona_afectada.numeroControl,
            "correo": incidencia.persona_afectada.correo,
            "estatus": incidencia.persona_afectada.estatus,
            "noIncidencias": incidencia.persona_afectada.noIncidencias,
        }
    
    reportante_dict = None
    if incidencia.reportante is not None:
        reportante_dict = {
            "id": incidencia.reportante.id,
            "nombre": incidencia.reportante.nombre,
            "numeroControl": incidencia.reportante.numeroControl,
            "correo": incidencia.reportante.correo,
        }
    
    auto_dict = None
    if incidencia.auto is not None:
        auto_dict = {
            "id": incidencia.auto.id,
            "placa": incidencia.auto.placa,
            "marca": incidencia.auto.marca,
            "modelo": incidencia.auto.modelo,
            "color": incidencia.auto.color,
        }
    
    return {
        "incidencia": incidencia_dict,
        "persona_afectada": persona_afectada_dict,
        "reportante": reportante_dict,
        "auto": auto_dict,
    }


@app.post("/ocr/placa")
async def ocr_placa(file: UploadFile = File(...)):
    global ocr
    if ocr is None:
        raise HTTPException(status_code=500, detail="OCR no inicializado")

    try:
        image_bytes = await file.read()
        if not image_bytes:
            raise ValueError("Imagen vacía")

        np_img = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(np_img, cv2.IMREAD_COLOR)
        if img is None:
            raise ValueError("No se pudo decodificar la imagen (cv2.imdecode dio None)")

        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as tmp:
            temp_path = Path(tmp.name)
            tmp.write(image_bytes)

        candidatos: list[tuple[str, float]] = []

        try:
            results = ocr.predict(str(temp_path))

            for res in results:
                data = res.json
                res_data = data.get("res", {})
                rec_texts = res_data.get("rec_texts", []) or []
                rec_scores = res_data.get("rec_scores", []) or []

                for t, s in zip(rec_texts, rec_scores):
                    if t and s is not None:
                        candidatos.append((str(t), float(s)))
        finally:
            try:
                temp_path.unlink(missing_ok=True)
            except Exception:
                pass

        if not candidatos:
            raise ValueError("No se pudo extraer texto de la placa")

        placa_candidatos: list[tuple[str, str, float]] = []

        for text, score in candidatos:
            norm = normalizar_placa(text)

            if len(norm) < 5 or len(norm) > 10:
                continue

            tiene_num = any(c.isdigit() for c in norm)
            tiene_letra = any(c.isalpha() for c in norm)

            if not (tiene_num and tiene_letra):
                continue

            placa_candidatos.append((text, norm, score))

        if placa_candidatos:
            placa_candidatos.sort(key=lambda x: x[2], reverse=True)
            texto_crudo, placa_norm, mejor_score = placa_candidatos[0]
        else:
            candidatos.sort(key=lambda x: x[1], reverse=True)
            texto_crudo, mejor_score = candidatos[0]
            placa_norm = normalizar_placa(texto_crudo)

        datos = buscar_en_bd_por_placa_norm(placa_norm)

        return {
            "ocr": {
                "texto_crudo": texto_crudo,
                "score": mejor_score,
                "placa_normalizada": placa_norm,
            },
            "match_bd": datos,
        }
    except Exception as e:
        raise HTTPException(status_code=400, detail=f"Error procesando la imagen: {e}")


# ========== Rutas Persona ==========

@app.get("/personas")
def listar_personas():
    db = SessionLocal()
    try:
        personas = db.query(Persona).all()
        return [
            {
                "id": p.id,
                "nombre": p.nombre,
                "edad": p.edad,
                "numeroControl": p.numeroControl,
                "correo": p.correo,
                "estatus": p.estatus,
                "noIncidencias": p.noIncidencias,
            }
            for p in personas
        ]
    finally:
        db.close()


@app.get("/personas/{persona_id}/autos")
def listar_autos_de_persona(persona_id: int):
    db = SessionLocal()
    try:
        persona = db.query(Persona).filter(Persona.id == persona_id).first()
        if not persona:
            raise HTTPException(status_code=404, detail="Persona no encontrada")

        autos = (
            db.query(Auto)
            .filter(Auto.persona_id == persona.id)
            .all()
        )

        return [
            {
                "id": a.id,
                "placa": a.placa,
                "marca": a.marca,
                "modelo": a.modelo,
                "color": a.color,
            }
            for a in autos
        ]
    finally:
        db.close()


@app.post("/personas/agregar", response_model=PersonaRead, status_code=201)
def añadir_persona(persona: PersonaCreate):
    db = SessionLocal()
    try:
        nueva_persona = Persona(
            nombre=persona.nombre,
            edad=persona.edad,
            numeroControl=persona.numeroControl,
            correo=persona.correo,
        )
        db.add(nueva_persona)
        db.commit()
        db.refresh(nueva_persona)
        return nueva_persona  
    finally:
        db.close()


@app.post("/personas/{persona_id}/autos", response_model=AutoRead, status_code=201)
def crear_auto_para_persona(persona_id: int, auto: AutoCreate):
    db = SessionLocal()
    try:
        persona = db.query(Persona).filter(Persona.id == persona_id).first()
        if not persona:
            raise HTTPException(status_code=404, detail="Persona no encontrada")

        nuevo_auto = Auto(
            placa=auto.placa,
            marca=auto.marca,
            modelo=auto.modelo,
            color=auto.color,
            persona_id=persona.id,
        )

        db.add(nuevo_auto)
        db.commit()
        db.refresh(nuevo_auto)

        return AutoRead(
            id=nuevo_auto.id,
            placa=nuevo_auto.placa,
            marca=nuevo_auto.marca,
            modelo=nuevo_auto.modelo,
            color=nuevo_auto.color,
            personaId=nuevo_auto.persona_id,
        )

    finally:
        db.close()


@app.delete("/personas/{persona_id}")
def eliminar_persona(persona_id: int):
    db = SessionLocal()
    try:
        persona = db.query(Persona).filter(Persona.id == persona_id).first()
        if not persona:
            raise HTTPException(status_code=404, detail="Persona no encontrada")
        db.delete(persona)
        db.commit()
        return {"detail": "Persona eliminada exitosamente"}
    finally:
        db.close()


@app.get("/personas/{persona_id}/detalle")
def obtener_detalle_persona(persona_id: int):
    db = SessionLocal()
    try:
        persona = db.query(Persona).filter(Persona.id == persona_id).first()
        if not persona:
            raise HTTPException(status_code=404, detail="Persona no encontrada")

        auto = db.query(Auto).filter(Auto.persona_id == persona.id).first()

        return respuesta_persona_auto(persona, auto)

    finally:
        db.close()

@app.get("/personas/{numero_control}", response_model=PersonaRead)
def obtener_persona_por_numero_control(numero_control: str):
    db = SessionLocal()
    try:
        persona = db.query(Persona).filter(Persona.numeroControl == numero_control).first()
        if persona is None:
            raise HTTPException(status_code=404, detail="Usuario no encontrado")
        return persona
    finally:
        db.close()



# ========== Rutas Auto ==========

@app.get("/autos")
def listar_autos():
    db = SessionLocal()
    try:
        autos = db.query(Auto).all()
        return [
            {
                "id": a.id,
                "placa": a.placa,
                "marca": a.marca,
                "modelo": a.modelo,
                "color": a.color,
                "personaId": a.persona_id,
            }
            for a in autos
        ]
    finally:
        db.close()


@app.get("/autos/placa/{placa}")
def buscar_datos_por_placa(placa: str):
    placa_norm = normalizar_placa(placa)
    datos = buscar_en_bd_por_placa_norm(placa_norm)

    if not datos:
        raise HTTPException(status_code=404, detail="Placa no registrada")

    return datos


@app.delete("/autos/{auto_id}")
def eliminar_auto(auto_id: int):
    db = SessionLocal()
    try:
        auto = db.query(Auto).filter(Auto.id == auto_id).first()
        if not auto:
            raise HTTPException(status_code=404, detail="Auto no encontrado")
        db.delete(auto)
        db.commit()
        return {"detail": "Auto eliminado exitosamente"}
    finally:
        db.close()


# ========== Rutas Incidencia ==========


@app.get("/incidencias")
def listar_incidencias(personaId: int):
    db = SessionLocal()
    try:
        persona = db.query(Persona).filter(Persona.id == personaId).first()
        if not persona:
            raise HTTPException(status_code=404, detail="Persona no encontrada")
        
        base_query = db.query(Incidencia).options(
            joinedload(Incidencia.persona_afectada),
            joinedload(Incidencia.reportante),
            joinedload(Incidencia.auto)
        )
        
        if persona.perfil.nombre == 'Usuario':
            incidencias = base_query.filter(Incidencia.reportante_id == personaId).all()
        else:
            incidencias = base_query.all()

        return [
            {
                "id": inc.id,
                "descripcion": inc.descripcion or "",  
                "fecha": inc.fecha or "", 
                "hora": inc.hora or "",
                "imagenes": json.loads(inc.imagenes) if inc.imagenes else [],
                "estatus": inc.estatus or "Pendiente",  
                "latitud": inc.latitud or "0",  
                "longitud": inc.longitud or "0",  
                "persona_afectada": {
                    "id": inc.persona_afectada.id,
                    "nombre": inc.persona_afectada.nombre or "",  
                    "numeroControl": inc.persona_afectada.numeroControl or "",  
                    "correo": inc.persona_afectada.correo or "",  
                    "estatus": inc.persona_afectada.estatus or "Autorizado",  
                    "noIncidencias": inc.persona_afectada.noIncidencias or 0  
                } if inc.persona_afectada else None,
                "reportante": {
                    "id": inc.reportante.id,
                    "nombre": inc.reportante.nombre or "", 
                    "numeroControl": inc.reportante.numeroControl or "",  
                    "correo": inc.reportante.correo or "" 
                } if inc.reportante else None,
                "auto": {
                    "id": inc.auto.id,
                    "placa": inc.auto.placa or "",  
                    "marca": inc.auto.marca or "",  
                    "modelo": inc.auto.modelo or "",  
                    "color": inc.auto.color or ""
                } if inc.auto else None
            }
            for inc in incidencias
        ]
    finally:
        db.close()


@app.post("/incidencias/agregar", status_code=201)
def añadir_incidencia(incidencia: IncidenciaCreate):
    db = SessionLocal()
    try:
        persona_afectada = db.query(Persona).filter(Persona.id == incidencia.personaId).first()
        if not persona_afectada:
            raise HTTPException(status_code=404, detail="Persona afectada no encontrada")
        
        reportante = db.query(Persona).filter(Persona.id == incidencia.reportanteId).first()
        if not reportante:
            raise HTTPException(status_code=404, detail="Reportante no encontrado")

        auto = db.query(Auto).filter(Auto.id == incidencia.autoId).first()
        if not auto:
            raise HTTPException(status_code=404, detail="Auto no encontrado")
        
        imagenes_str = json.dumps(incidencia.imagenes) if incidencia.imagenes else "[]"
        
        latitud = incidencia.latitud if incidencia.latitud is not None else "0"
        longitud = incidencia.longitud if incidencia.longitud is not None else "0"
        hora = incidencia.hora if incidencia.hora is not None else ""
        nueva_incidencia = Incidencia(
            descripcion=incidencia.descripcion,
            fecha=incidencia.fecha,
            hora=hora,
            imagenes=imagenes_str,
            estatus=incidencia.estatus or "Pendiente",
            latitud=latitud,  
            longitud=longitud, 
            persona_id=incidencia.personaId,
            reportante_id=incidencia.reportanteId,
            auto_id=incidencia.autoId,
        )
        db.add(nueva_incidencia)
        db.commit()
        db.refresh(nueva_incidencia)
        
        return IncidenciaRead(
            id=nueva_incidencia.id,
            descripcion=nueva_incidencia.descripcion,
            fecha=nueva_incidencia.fecha,
            hora=nueva_incidencia.hora,
            imagenes=json.loads(nueva_incidencia.imagenes) if nueva_incidencia.imagenes else [],
            estatus=nueva_incidencia.estatus,
            latitud=nueva_incidencia.latitud,
            longitud=nueva_incidencia.longitud,
            personaId=nueva_incidencia.persona_id,
            reportanteId=nueva_incidencia.reportante_id,
            autoId=nueva_incidencia.auto_id,
        )
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=400, detail=f"Error creando incidencia: {str(e)}")
    finally:
        db.close()


@app.delete("/incidencias/{incidencia_id}")
def eliminar_incidencia(incidencia_id: int):
    db = SessionLocal()
    try:
        incidencia = db.query(Incidencia).filter(Incidencia.id == incidencia_id).first()
        if not incidencia:
            raise HTTPException(status_code=404, detail="Incidencia no encontrada")
        db.delete(incidencia)
        db.commit()
        return {"detail": "Incidencia eliminada exitosamente"}
    finally:
        db.close()


@app.get("/incidencias/{incidencia_id}/detalle")
def obtener_detalle_incidencia(incidencia_id: int):
    db = SessionLocal()
    try:
        incidencia = db.query(Incidencia).options(
            joinedload(Incidencia.persona_afectada),
            joinedload(Incidencia.reportante),
            joinedload(Incidencia.auto)
        ).filter(Incidencia.id == incidencia_id).first()
        
        if not incidencia:
            raise HTTPException(status_code=404, detail="Incidencia no encontrada")

        return respuesta_incidencia(incidencia)

    finally:
        db.close()


@app.patch("/incidencias/{incidencia_id}/estatus")
def actualizar_estatus_incidencia(incidencia_id: int, estatus: str):
    db = SessionLocal()
    try:
        incidencia = db.query(Incidencia).options(
            joinedload(Incidencia.persona_afectada),
            joinedload(Incidencia.reportante),
            joinedload(Incidencia.auto)
        ).filter(Incidencia.id == incidencia_id).first()
        
        if not incidencia:
            raise HTTPException(status_code=404, detail="Incidencia no encontrada")

        persona_afectada = incidencia.persona_afectada
        reportante = incidencia.reportante
        auto = incidencia.auto
        
        if not persona_afectada or not auto or not reportante:
            raise HTTPException(status_code=404, detail="Datos relacionados no encontrados")

        incidencia.estatus = estatus
        
        if estatus == "Aprobada":
            persona_afectada.noIncidencias += 1
            
            if persona_afectada.noIncidencias >= 3:
                persona_afectada.estatus = "Bloqueado"
            
            db.commit()
            
            try:
                enviar_correo_persona_afectada(
                    nombre=persona_afectada.nombre,
                    email=persona_afectada.correo,
                    numero_incidencias=persona_afectada.noIncidencias,
                    fecha=incidencia.fecha,
                    hora=incidencia.hora,
                    descripcion=incidencia.descripcion,
                    marca=auto.marca,
                    modelo=auto.modelo,
                    placa=auto.placa,
                    incidencia_id=incidencia.id
                )
                print(f"Correo enviado a persona afectada: {persona_afectada.correo}")
            except Exception as e:
                print(f"Error enviando correo a persona afectada: {e}")
            
            try:
                enviar_correo_reportante(
                    email_reportante=reportante.correo,
                    incidencia_id=incidencia.id,
                    fecha=incidencia.fecha,
                    hora=incidencia.hora,
                    descripcion=incidencia.descripcion,
                    marca=auto.marca,
                    modelo=auto.modelo,
                    placa=auto.placa
                )
                print(f"Correo enviado al reportante: {reportante.correo}")
            except Exception as e:
                print(f"Error enviando correo al reportante: {e}")
            
            mensaje = f"Incidencia aprobada. Total de incidencias: {persona_afectada.noIncidencias}"
            if persona_afectada.estatus == "Bloqueado":
                mensaje += ". ⚠️ Usuario BLOQUEADO."
            
            return {
                "message": mensaje,
                "incidencia_id": incidencia.id,
                "estatus": incidencia.estatus,
                "persona_afectada": {
                    "id": persona_afectada.id,
                    "nombre": persona_afectada.nombre,
                    "noIncidencias": persona_afectada.noIncidencias,
                    "estatus": persona_afectada.estatus
                },
                "reportante": {
                    "id": reportante.id,
                    "nombre": reportante.nombre,
                    "correo": reportante.correo
                }
            }
        
        elif estatus == "Rechazada":
            db.commit()
            
            try:
                enviar_correo_incidencia_rechazada(
                    email_reportante=reportante.correo,
                    incidencia_id=incidencia.id,
                    fecha=incidencia.fecha,
                    hora=incidencia.hora,
                    descripcion=incidencia.descripcion
                )
                print(f"Correo de rechazo enviado al reportante: {reportante.correo}")
            except Exception as e:
                print(f"Error enviando correo de rechazo: {e}")
            
            return {
                "message": "Incidencia rechazada. Correo enviado al reportante.",
                "incidencia_id": incidencia.id,
                "estatus": incidencia.estatus,
                "reportante": {
                    "id": reportante.id,
                    "nombre": reportante.nombre,
                    "correo": reportante.correo
                }
            }
        
        else:
            db.commit()
            return {
                "message": f"Estatus actualizado a: {estatus}",
                "incidencia_id": incidencia.id,
                "estatus": incidencia.estatus
            }
            
    except HTTPException:
        raise
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=f"Error actualizando incidencia: {str(e)}")
    finally:
        db.close()