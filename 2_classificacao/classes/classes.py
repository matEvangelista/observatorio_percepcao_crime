from pydantic import BaseModel, Field
from typing import Annotated, List, TypedDict, Optional, Literal
from enum import IntEnum
from langchain_core.messages import BaseMessage
from langgraph.graph import add_messages

class TipoAutorEnum(IntEnum):
    POLICIAL = 1
    MILICIANO = 2
    TRAFICANTE = 3
    ASSALTANTE = 4
    FURTADOR = 5
    HOMICIDA = 6
    AGRESSOR = 7
    ESTUPRADOR = 8
    SEQUESTRADOR = 9
    EXTORSIONARIO = 10
    ESTELIONATARIO = 11
    USUARIO_DE_DROGAS = 12
    AUTOR_CULPOSO = 13
    POLITICO = 14
    AUTOR_NAO_IDENTIFICADO = 15
    OUTROS = 16
    SEM_CRIME = 17

class TipoCrimeEnum(IntEnum):
    HOMICIDIO_DOLOSO = 1
    LESAO_CORPORAL_SEGUIDA_DE_MORTE = 2
    LATROCINIO = 3
    MORTE_INTERVENCAO_POLICIAL = 4
    LETALIDADE_VIOLENTA = 5
    TENTATIVA_HOMICIDIO = 6
    LESAO_CORPORAL_DOLOSA = 7
    ESTUPRO = 8
    HOMICIDIO_CULPOSO = 9
    LESAO_CORPORAL_CULPOSA = 10
    ROUBO_TRANSEUNTE = 11
    ROUBO_CELULAR = 12
    ROUBO_EM_COLETIVO = 13
    ROUBO_VEICULO = 14
    ROUBO_CARGA = 15
    ROUBO_COMERCIO = 16
    ROUBO_RESIDENCIA = 17
    ROUBO_BANCO = 18
    ROUBO_CAIXA_ELETRONICO = 19
    ROUBO_CONDUCAO_SAQUE = 20
    ROUBO_APOS_SAQUE = 21
    ROUBO_BICICLETA = 22
    OUTROS_ROUBOS = 23
    FURTO_VEICULOS = 24
    FURTO_TRANSEUNTE = 25
    FURTO_COLETIVO = 26
    FURTO_CELULAR = 27
    FURTO_BICICLETA = 28
    OUTROS_FURTOS = 29
    SEQUESTRO = 30
    EXTORSAO = 31
    SEQUESTRO_RElampago = 32
    ESTELIONATO = 33
    POSSE_DROGAS = 34
    TRAFICO_DROGAS = 35
    AMEACA = 36
    PESSOAS_DESAPARECIDAS = 37
    ENCONTRO_CADAVER = 38
    POLICIAIS_MORTOS_EM_SERVICO = 39
    TIROS = 40
    OUTROS = 41
    SEM_CRIME = 42


class EventoClassificado(BaseModel):
    """
    Representa um evento de segurança classificado com base nas tabelas oficiais.
    """
    raciocinio: str = Field(
        ...,
        description="Escreva, de forma sequencial, o porquê das associações"
    )
    local: str = Field(
        ..., 
        description="O local do crime e todas as suas menções extraídas do texto. Ex: 'na Avenida Brasil', 'Complexo do Alemão'. Se não houver, use 'Não identificado'."
    )
    autor: TipoAutorEnum = Field(
        ..., 
        description="A classificação do autor escolhida estritamente da lista permitida."
    )
    crime: TipoCrimeEnum = Field(
        ..., 
        description="A tipificação do crime escolhida estritamente da lista permitida."
    )
    grupo: Literal['Tráfico não identificado', 'Comando Vermelho', 'Terceiro Comando Puro', 'Milícia', 'Amigo dos Amigos', 'Nulo'] = Field(
        ...,
        description="Tipo de grupo do crime se houver. Comando Vermelho pode ser mencionado como CV; Terceiro Comando Puro, como TCP; e Amigos dos Amigos, como ADA. Utilize 'Tráfico não identificado' caso nenhum desses grupos seja mencionado. Classifique milicianos como milícia"
    )
    id: int = Field(..., description="ID gerado pela LLM para a publicacao")

class ItemLocalizacao(BaseModel):
    id_endereco_original: int = Field(..., description="ID do evento original.")
    id_bairro_db: int = Field(..., description="ID do bairro encontrado (0 se não achou).")
    # Este campo já existia, mas agora será obrigatório preencher se houver info
    logradouro_normalizado: Optional[str] = Field(None, description="Nome da rua/avenida encontrada (ex: 'Avenida Brasil').")

# Output Final do Grafo
class EventoEnriquecido(EventoClassificado):
    bairro_id: int = Field(default=0)
    logradouro: Optional[str] = Field(default=None, description="Endereço ou rua específica, se identificado.")

class ListaDeEventos(BaseModel):
    """Lista contendo todos os eventos identificados e classificados."""
    eventos: List[EventoClassificado]

class ClassificacaoRelevancia(BaseModel):
    """Classificação binária para triagem de textos de segurança pública."""
    motivo: str = Field(
        ...,
        description="Breve explicação (max 10 palavras) do porquê foi aceito ou rejeitado."
    )
    eh_relevante: bool = Field(
        ..., 
        description="True se o texto relata um evento de segurança, crime, violência, operação policial ou movimentação atípica. False se for apenas opinião, oração, spam ou política."
    )

class GraphState(TypedDict):
    texto_input: str
    eh_relevante: bool
    eventos_crimes: ListaDeEventos
    eventos_finais: List[EventoEnriquecido] 
    messages: Annotated[List[BaseMessage], add_messages]
    erro_validacao: Optional[str] # A "bronca" no LLM
    tentativas_validacao: int     # Contador para evitar loop infinito

class GraphStateComentario(GraphState):
    contexto_autores: str
    contexto_crimes: str
    contexto_local: str

from langchain_core.output_parsers import PydanticOutputParser

# 1. Defina o objeto de cada item
class LocalizacaoIdentificada(BaseModel):
    id: int = Field(..., description="ID do bairro encontrado no banco (0 se não achou)")
    logradouro: Optional[str] = Field(None, description="Nome da rua/avenida normalizada")
    id_endereco: int = Field(..., description="ID de vínculo original do evento")

# 2. Defina o container (Lista)
class ListaDeLocalizacoes(BaseModel):
    resultados: List[LocalizacaoIdentificada]

class HouveCrime(BaseModel):
    ha_crime: Literal['Sim', 'Não'] = Field(
        ..., 
        description="Responda 'Sim' se o texto descreve um evento de crime, violência ou operação policial. Responda 'Não' para opiniões, orações, reclamações genéricas ou spam."
    )

class LocalizacaoFinal(BaseModel):
    id_endereco_original: int = Field(..., description="O ID original do evento que você recebeu no input.")
    id_bairro_db: int = Field(..., description="O ID numérico do bairro encontrado no banco (0 se não achou).")
    logradouro_normalizado: Optional[str] = Field(None, description="Nome da rua/avenida limpo e oficial. Null se não houver.")

# Estrutura da Lista Final (A ferramenta de entrega)
class SubmeterLocalizacoes(BaseModel):
    """Chame esta ferramenta APENAS quando tiver processado TODOS os endereços da lista ou quando não houver lista."""
    resultados: List[LocalizacaoFinal]