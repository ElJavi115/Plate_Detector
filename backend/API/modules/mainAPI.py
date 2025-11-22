from fastapi import FastAPI, HTTPException, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from paddleocr import PaddleOCR
from tempfile import NamedTemporaryFile

from .config import Base, engine, SessionLocal
from .models import Auto, Persona

app = FastAPI(title="API Placas", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

ocr = PaddleOCR(use_angle_cls=True, lang='en')

@app.on_event("startup")
def startup():
    Base.metadata.create_all(bind=engine)
    cargar_datos_iniciales()


def cargar_datos_iniciales():
    db = SessionLocal()
    try:
        # si ya hay personas, no volvemos a insertar
        if db.query(Persona).first():
            print("Datos ya cargados.")
            return

        datos = [
            {
                "persona": {
                    "nombre": "Juan",
                    "edad": 30,
                    "numeroControl": "123456",
                    "correo": "juan@example.com",
                },
                "auto": {
                    "placa": "A00-AAA",
                    "marca": "Nissan",
                    "modelo": "Sentra",
                    "color": "Rojo",
                },
            },
            {
                "persona": {
                    "nombre": "Ana",
                    "edad": 28,
                    "numeroControl": "654321",
                    "correo": "ana@example.com",
                },
                "auto": {
                    "placa": "NA-86-83",
                    "marca": "Toyota",
                    "modelo": "Corolla",
                    "color": "Azul",
                },
            },
            {
                "persona": {
                    "nombre": "Carlos",
                    "edad": 40,
                    "numeroControl": "112233",
                    "correo": "carlos@example.com",
                },
                "auto": {
                    "placa": "BBB222",
                    "marca": "Honda",
                    "modelo": "Civic",
                    "color": "Negro",
                },
            },
        ]

        for item in datos:
            persona = Persona(**item["persona"])
            db.add(persona)
            db.commit()
            db.refresh(persona)

            auto = Auto(**item["auto"], persona_id=persona.id)
            db.add(auto)
            db.commit()
    finally:
        db.close()


@app.get("/autos/placa/{placa}")
def buscar_datos_por_placa(placa: str):
    db = SessionLocal()
    try:
        consulta = (
            db.query(Auto)
            .join(Persona)
            .filter(Auto.placa == placa)
            .first()
        )

        if not consulta:
            raise HTTPException(status_code=404, detail="Placa no registrada")

        respuesta = {
            "persona": {
                "nombre": consulta.persona.nombre,
                "edad": consulta.persona.edad,
                "correo": consulta.persona.correo,
            },
            "auto": {
                "placa": consulta.placa,
                "marca": consulta.marca,
                "modelo": consulta.modelo,
                "color": consulta.color,
            },
        }
        return respuesta
    finally:
        db.close()


def normalizar_placa(texto: str) -> str:
    texto = texto.upper().strip()
    texto = texto.replace(" ", "")
    # texto = texto.replace("-", "")  # descomenta si quieres ignorar guiones
    return texto


@app.post("/ocr-placa")
async def ocr_placa(file: UploadFile = File(...)):
    with NamedTemporaryFile(delete=True, suffix=".jpg") as tmp:
        contenido = await file.read()
        tmp.write(contenido)
        tmp.flush()

        result = ocr.ocr(tmp.name, cls=True)

    textos = []
    for line in result:
        for box, (text, score) in line:
            if score > 0.5:
                textos.append(text)

    if not textos:
        raise HTTPException(status_code=400, detail="No se detectó texto en la imagen")

    placa_detectada = normalizar_placa(textos[0])
    print("Placa detectada por OCR:", placa_detectada)

    db = SessionLocal()
    try:
        consulta = (
            db.query(Auto)
            .join(Persona)
            .filter(Auto.placa == placa_detectada)
            .first()
        )

        if not consulta:
            raise HTTPException(
                status_code=404,
                detail=f"Placa {placa_detectada} no registrada",
            )

        respuesta = {
            "persona": {
                "nombre": consulta.persona.nombre,
                "edad": consulta.persona.edad,
                "correo": consulta.persona.correo,
            },
            "auto": {
                "placa": consulta.placa,
                "marca": consulta.marca,
                "modelo": consulta.modelo,
                "color": consulta.color,
            },
        }
        return respuesta
    finally:
        db.close()
