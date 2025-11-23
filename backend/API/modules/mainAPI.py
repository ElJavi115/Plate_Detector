from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware

from .config import Base, engine, SessionLocal
from .models import Auto, Persona

from paddleocr import PaddleOCR
import numpy as np
import cv2
import logging
import tempfile
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
    cargar_datos_iniciales()

    ocr = PaddleOCR(
        lang="en",
        use_doc_orientation_classify=False,
        use_doc_unwarping=False,
        use_textline_orientation=False,
    )

def cargar_datos_iniciales():
    db = SessionLocal()
    try:
        if db.query(Persona).first():
            print("Datos ya cargados.")
            return

        datos = [
            {
                "persona": {
                    "nombre": "Candelario Javier Uribe Corrales",
                    "edad": 54,
                    "numeroControl": "123456",
                    "correo": "javier@example.com",
                    "estatus": "Autorizado",
                    "noIncidencias": 0,
                },
                "autos": [
                    {
                        "placa": "VKT-014-B",
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
                "id": str(consulta.persona.id),
                "nombre": consulta.persona.nombre,
                "edad": consulta.persona.edad,
                "numeroControl": consulta.persona.numeroControl,
                "correo": consulta.persona.correo,
                "estatus": consulta.persona.estatus,
                "noIncidencias": consulta.persona.noIncidencias,
            },
            "auto": {
                "id": str(consulta.id),
                "placa": consulta.placa,
                "marca": consulta.marca,
                "modelo": consulta.modelo,
                "color": consulta.color,
            },
        }
        return respuesta
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
                "id": str(a.id),
                "placa": a.placa,
                "marca": a.marca,
                "modelo": a.modelo,
                "color": a.color,
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


def respuesta_persona_auto(persona: Persona, auto: Auto | None):
    persona_dict = {
        "id": str(persona.id),
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
            "id": str(auto.id),
            "placa": auto.placa,
            "marca": auto.marca,
            "modelo": auto.modelo,
            "color": auto.color,
        }

    return {
        "persona": persona_dict,
        "auto": auto_dict,
    }


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


@app.post("/ocr/placa")
async def ocr_placa(file: UploadFile = File(...)):
    """
    Recibe una imagen, extrae texto con PaddleOCR, normaliza la placa
    y busca en la BD.
    """
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


@app.get("/personas")
def listar_personas():
    db = SessionLocal()
    try:
        personas = db.query(Persona).all()
        return [
            {
                "id": str(p.id),
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


@app.get("/autos")
def listar_autos():
    db = SessionLocal()
    try:
        autos = db.query(Auto).all()
        return [
            {
                "id": str(a.id),
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


@app.get("/personas/debug")
def debug_todas_las_personas():
    db = SessionLocal()
    try:
        personas = db.query(Persona).all()
        resultado = []
        for persona in personas:
            autos = [
                {
                    "placa": auto.placa,
                    "marca": auto.marca,
                    "modelo": auto.modelo,
                    "color": auto.color,
                }
                for auto in persona.autos
            ]
            resultado.append(
                {
                    "nombre": persona.nombre,
                    "edad": persona.edad,
                    "numeroControl": persona.numeroControl,
                    "correo": persona.correo,
                    "estatus": persona.estatus,
                    "noIncidencias": persona.noIncidencias,
                    "autos": autos,
                }
            )
        return resultado
    finally:
        db.close()


@app.get("/autos/debug")
def debug_todos_los_autos():
    db = SessionLocal()
    try:
        autos = db.query(Auto).all()
        resultado = []
        for auto in autos:
            resultado.append(
                {
                    "placa": auto.placa,
                    "marca": auto.marca,
                    "modelo": auto.modelo,
                    "color": auto.color,
                    "persona": {
                        "nombre": auto.persona.nombre,
                        "edad": auto.persona.edad,
                        "correo": auto.persona.correo,
                        "estatus": auto.persona.estatus,
                        "noIncidencias": auto.persona.noIncidencias,
                    },
                }
            )
        return resultado
    finally:
        db.close()
