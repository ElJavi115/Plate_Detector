from sqlalchemy import Column, Integer, String, ForeignKey, UniqueConstraint
from sqlalchemy.orm import relationship
from .config import Base

class Persona(Base):
    __tablename__ = 'personas'

    id = Column(Integer, primary_key=True, index=True)
    nombre = Column(String, nullable=False)
    edad = Column(Integer, nullable=False)
    correo = Column(String, unique=True, nullable=False)
    autos = relationship("Auto", back_populates="persona")

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