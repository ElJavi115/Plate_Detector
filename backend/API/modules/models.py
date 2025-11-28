from sqlalchemy import Column, Integer, String, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from .config import Base

class Incidencia(Base):
    __tablename__ = 'incidencias'

    id = Column(Integer, primary_key=True, index=True)
    descripcion = Column(String, nullable=False)
    fecha = Column(String, nullable=False)
    hora = Column(String, nullable=True)
    imagenes = Column(String, nullable=True) 
    estatus = Column(String, default="Pendiente") 
    latitud = Column(String, nullable=True)
    longitud = Column(String, nullable=True)
    persona_id = Column(Integer, ForeignKey('personas.id', ondelete = "CASCADE"), nullable=False)
    reportante_id = Column(Integer, ForeignKey('personas.id', ondelete = "CASCADE"), nullable=False)
    auto_id = Column(Integer, ForeignKey('autos.id', ondelete = "CASCADE"), nullable=False)

    persona_afectada = relationship(
        "Persona",
        foreign_keys=[persona_id], 
        back_populates="incidencias_afectado"
    )
    
    reportante = relationship(
        "Persona",
        foreign_keys=[reportante_id],
        back_populates="incidencias_reportante"
    )
    
    auto = relationship("Auto", back_populates="incidencias")
class Persona(Base):
    __tablename__ = 'personas'

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, nullable=False)
    edad = Column(Integer, nullable=False)
    numeroControl = Column(String, unique=True, nullable=False)
    correo = Column(String, unique=True, nullable=False)
    estatus = Column(String, nullable=False, default="Autorizado")
    noIncidencias = Column(Integer, nullable=False, default=0)
    autos = relationship("Auto", back_populates="persona")
    perfil_id = Column(Integer, ForeignKey('perfiles.id', ondelete="SET NULL"), nullable=True, default=1)

    perfil = relationship("Perfil", back_populates="personas")
    incidencias_afectado = relationship(
        "Incidencia",
        foreign_keys=[Incidencia.persona_id],  
        back_populates="persona_afectada"
    )

    incidencias_reportante = relationship(
        "Incidencia",
        foreign_keys=[Incidencia.reportante_id],  
        back_populates="reportante"
    )

class Auto(Base):
    __tablename__ = 'autos'
    __table_args__ = (UniqueConstraint('placa', name='uq_placa'),)

    id = Column(Integer, primary_key=True, index=True)
    marca = Column(String, nullable=False)
    modelo = Column(String, nullable=False)
    color = Column(String, nullable=False)
    placa = Column(String, nullable=False, unique=True, index=True)
    persona_id = Column(Integer, ForeignKey('personas.id', ondelete = "CASCADE"), nullable=False)

    persona = relationship("Persona", back_populates="autos")
    incidencias = relationship("Incidencia", back_populates="auto")

class Perfil(Base):
    __tablename__ = 'perfiles'

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, nullable=False)
    descripcion = Column(String, nullable=True)

    personas = relationship("Persona", back_populates="perfil")