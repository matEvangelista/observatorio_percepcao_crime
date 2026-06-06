from langchain_core.prompts import ChatPromptTemplate
from langchain_openai.chat_models import ChatOpenAI
from langchain_ollama import ChatOllama
from langchain_google_genai import ChatGoogleGenerativeAI
from langchain.messages import SystemMessage, HumanMessage, AIMessage
from langgraph.prebuilt import ToolNode, tools_condition
from dotenv import load_dotenv
from typing import List
from classes.classes import GraphState, ListaDeEventos, ListaDeLocalizacoes, HouveCrime, GraphStateComentario, ClassificacaoRelevancia, LocalizacaoFinal, SubmeterLocalizacoes, EventoEnriquecido, TipoAutorEnum, TipoCrimeEnum
from tools.tools import tools_geo
import re
from langchain_core.prompts import PromptTemplate
import json
import ast
from langgraph.graph import END, START
from typing import Literal
load_dotenv()

llm = ChatOpenAI(
    model="sabia-4",
    base_url="https://chat.maritaca.ai/api",
    temperature=0,
    top_p=1,
    frequency_penalty=0,
    presence_penalty=0,
    seed=42,
    timeout=300,
    max_retries=3
)

llm2 = ChatOpenAI(
    model="sabiazinho-4",
    base_url="https://chat.maritaca.ai/api",
    temperature=0,
    top_p=1,
    frequency_penalty=0,
    presence_penalty=0,
    seed=42,
    timeout=300,
    max_retries=3
)

llm_gemini = ChatGoogleGenerativeAI(
    model="gemini-2.5-flash", # O 'flash' é rápido e ótimo para tasks repetitivas. Use 'pro' se precisar de mais raciocínio.
    temperature=0,
    max_retries=3,
    timeout=None
)

####################### TRIAGEM ########################
system_prompt_triagem = """
Você é um sistema de triagem de crimes.
Sua missão é filtrar mensagens irrelevantes e deixar passar APENAS relatos de crimes ou de movimentação policial.

CRITÉRIOS PARA APROVAR (True):
- Relatos de crime ou de personagens que cometem crimes, incluindo operações policiais.
- Todos os relatos de mortes, descrições de ameaça, tiros, atividade policial, roubos, furtos, violência, golpes, fraudes etc.
- Menções a facções (Comando Vermelho, Terceiro Comando Puro, Amigo dos Amigos) ou Milícia.
- Menções a atividades da polícia

CRITÉRIOS PARA REJEITAR (False):
- Orações (Ex: "Deus proteja", "Livrai-nos do mal").
- Comentários puramente políticos ("Governador incompetente", "Culpa do prefeito").
- Reclamações de serviços (luz, água, buraco, lixo).
- Insultos genéricos sem descrição de evento.
- Perguntas vagas (Ex: "Alguém sabe o que houve?").

Seja rigoroso. Na dúvida se é um evento real ou apenas boato vago, aprove para análise posterior.
"""

prompt_triagem = ChatPromptTemplate.from_messages([
    ("system", system_prompt_triagem),
    ("user", "{texto_input}")
])

triagem_chain = prompt_triagem | llm.with_structured_output(ClassificacaoRelevancia)

def node_triagem(state: GraphState):
    texto = state['texto_input']
    
    try:
        resultado = triagem_chain.invoke({"texto_input": texto})
        eh_relevante = resultado.eh_relevante
        
    except Exception as e:
        eh_relevante = False

    # Retorna apenas a atualização do estado
    return {"eh_relevante": eh_relevante}

# Lógica de Decisão da Triagem (Crime vs Não Crime)
def router_triagem(state: GraphState):
    if state['eh_relevante']:
        return "extrator" # Segue o baile
    else:
        return END # Encerra para economizar
##########################################################

system_prompt_completo = """
Você é um classificador de textos sociológico de alta precisão e um especialista em segurança pública do Rio de Janeiro.
Sua tarefa é ler um texto, identificar **TODOS os eventos de crime** (ou seja, combinação entre autor, crime, local e nome do crime organizado do autor) e retornar uma lista estruturada com Local, id do Autor e id do Crime e nome do grupo do crime organizado do autor.

Classifique apenas descrições de crime. Anseios como "merece morrer", "tem que matar mesmo" etc **NÃO SÃO** registros de crime, mas apenas pedidos, e não devem ser considerados. Gere um id simples para cada evento de crime. Envie o local completo, mencionado, não trechos dele. Caso o local não seja identificado ou seja genérico (como, "na minha rua"), responda com "Não Identificado".
Locais como "arredores de", "próximo a" devem ser registrados apenas com o local a que se referencia. Exemplo: "Arredores da curicica" -> "Curicica"
Trate o nome dos locais, corrigindo erros de português e expandindo abreviações (como Av para Avenida). 

VOCÊ DEVE SEMPRE RACIOCINAR DE FORMA SEQUENCIAL

## FONTES
Você DEVE usar as definições abaixo como sua única fonte de verdade.

### TABELA DE AUTORES (Hierarquia de Decisão):
Use esta lógica para escolher o autor. Se o texto mencionar um status (Grupo 1), ele tem prioridade. Se descrever apenas a ação (Grupo 2), use o papel correspondente. Só use "Não Identificado" se não se encaixar nos anteriores.

**GRUPO 1: STATUS SOCIAL/FACÇÃO (Prioridade Alta)**
1 - **Policial** - Membro de força policial (militar ou civil). Prioridade sobre a ação (ex: Policial que mata é Policial, não Homicida).
2 - **Miliciano** - Membro de milícia/paramilitar.
3 - **Traficante** - Membro do tráfico.
12 - **Usuário de Drogas** - Consumidor.
14 - **Político** - Cargo político.

**GRUPO 2: PAPEL DEFINIDO PELA AÇÃO (Use se não houver Status acima)**
4 - **Assaltante** - Quem pratica roubo (violência/ameaça). Ex: "Levaram meu carro armado" -> Autor: Assaltante.
5 - **Furtador** - Quem pratica furto (sem violência). Ex: "Sumiu minha carteira" -> Autor: Furtador.
6 - **Homicida** - Quem mata (exceto se for policial/traficante/miliciano identificado). Ex: "Mataram o rapaz" -> Autor: Homicida.
7 - **Agressor** - Quem bate/agride.
8 - **Estuprador** - Quem comete crime sexual.
9 - **Sequestrador** - Quem sequestra.
10 - **Extorsionário** - Quem extorque.
11 - **Estelionatário** - Quem aplica golpes.

**GRUPO 3: OUTROS/INCERTEZA (Prioridade Baixa)**
13 - **Autor Culposo** - Sem intenção (acidentes).
16 - **Outros** - Autor identificado mas fora das categorias acima.
15 - **Autor não identificado** - APENAS para crimes de resultado onde o agente é invisível ou desconhecido (ex: "Bala perdida", "Corpo encontrado", "Tiros ouvidos longe").
17 - **Sem Crime** - Quando não há crime.

### TABELA DE CRIMES (Escolha um):
id - Crime - Descrição:
1 - **Homicídio Doloso** - Matar alguém com dolo.
2 - **Lesão Corporal Seguida de Morte** - Lesão que resulta em morte sem intenção de matar.
3 - **Latrocínio** - Roubo seguido de morte.
4 - **Morte por Intervenção Policial** - Morte causada por policial.
5 - **Letalidade Violenta** - Soma de homicídios dolosos, latrocínios, etc.
6 - **Tentativa de Homicídio** - Tentar matar.
7 - **Lesão Corporal Dolosa** - Agressão intencional.
8 - **Estupro** - Violência sexual.
9 - **Homicídio Culposo** - Matar sem intenção (trânsito, imperícia).
10 - **Lesão Corporal Culposa** - Ferir sem intenção.
11 - **Roubo Transeunte** - Assalto a pedestre.
12 - **Roubo Celular** - Assalto levando celular.
13 - **Roubo em Coletivo** - Assalto em ônibus/trem/metrô.
14 - **Roubo Veículo** - Assalto levando carro/moto.
15 - **Roubo Carga** - Roubo de carga.
16 - **Roubo Comércio** - Assalto a loja/mercado.
17 - **Roubo Residência** - Assalto dentro de casa.
18 - **Roubo Banco** - Assalto a banco.
19 - **Roubo Caixa Eletrônico** - Explodir/roubar caixa.
20 - **Roubo Condução Saque** - "Saidinha de banco" (antes do saque/durante).
21 - **Roubo Após Saque** - "Saidinha de banco" (após).
22 - **Roubo Bicicleta** - Roubo de bike.
23 - **Outros Roubos** - Roubo genérico com violência.
24 - **Furto Veículos** - Levar veículo sem violência (estacionado).
25 - **Furto Transeunte** - Punguista (sem a vítima ver).
26 - **Furto Coletivo** - Furto em transporte.
27 - **Furto Celular** - Furto de celular.
28 - **Furto Bicicleta** - Furto de bike.
29 - **Outros Furtos** - Furto genérico.
30 - **Sequestro** - Cárcere privado/Resgate.
31 - **Extorsão** - Chantagem/Cobrança indevida.
32 - **Sequestro Relâmpago** - Retenção rápida para saque.
33 - **Estelionato** - Fraude/Golpe.
34 - **Posse Drogas** - Uso próprio.
35 - **Tráfico Drogas** - Venda/Transporte.
36 - **Ameaça** - Ameaça verbal ou física.
37 - **Pessoas Desaparecidas** - Sumiço de pessoa.
38 - **Encontro Cadáver** - Achar corpo.
39 - **Policiais Mortos em Serviço** - Morte de policial.
41 - **Tiros** - Disparos de arma de fogo (origem incerta).
40 - **Outros** - Outros crimes.
42 - **Sem Crime** - Não há crime.

### TABELA DE GRUPOS CRIMINOSOS:
- 'Comando Vermelho': CV, C.V, Comando, "Tudo 2", "Vermelhão".
- 'Terceiro Comando Puro': TCP, Terceiro, "Tudo 3", "Israel".
- 'Amigo dos Amigos': ADA.
- 'Milícia': Milicianos, "Tropa do X", "Bonde do Zinho", "Narcomilícia".
- 'Tráfico não identificado': Quando é claramente tráfico ou traficante, mas a facção não é citada.
- 'Nulo': Para crimes sem relação com crime organizado (ex: briga de bar, assalto comum, violência doméstica, acidente).

### REGRAS DE COMBINAÇÃO OBRIGATÓRIAS (Lógica Rígida):
1. **HIERARQUIA DE AUTOR:**
   - Se o texto diz "Traficantes roubaram", Autor = Traficante (ID 3).
   - Se o texto diz "Roubaram meu carro" (sem citar quem), Autor = Assaltante (ID 4). **NÃO USE** Autor não identificado neste caso, pois a ação define o papel.
   - Se o texto diz "Mataram ele" (sem citar quem), Autor = Homicida (ID 6).

2. **POLICIAIS:** Se Autor é Policial (ID 1) e o ato é matar, Crime = Morte por Intervenção Policial (ID 4).

3. **LATROCÍNIO:** Roubo + Morte da vítima = Latrocínio (ID 3).

4. **AUTOR NÃO IDENTIFICADO (ID 15):** Use estritamente para fenômenos sem agente claro no texto.
   - CORRETO: "Ouvimos muitos tiros" (Crime: Tiros, Autor: Não Identificado).
   - CORRETO: "Corpo achado no mato" (Crime: Encontro Cadáver, Autor: Não Identificado).
   - CORRETO: "Sumiu meu filho" (Crime: Pessoas Desaparecidas, Autor: Não Identificado).
   - ERRADO: "Me assaltaram" (Isso é Autor: Assaltante).
   - ERRADO: "Estupraram a menina" (Isso é Autor: Estuprador).

5. **REGRA DE GRUPO:** Se o autor for Assaltante, Furtador, Homicida (civil), Estuprador, etc., o Grupo geralmente é 'Nulo', a menos que o texto vincule explicitamente ao tráfico/milícia.

## Exemplo de raciocínio 1
Texto: "Assaltaram o ônibus 306 na Avenida Brasil. Levaram tudo."
Raciocínio:
- Ação: Assaltar (Roubo em Coletivo).
- Quem? Sujeito indeterminado ("Assaltaram").
- Status mencionado? Não.
- Definição pelo Ato: Quem assalta é Assaltante.
JSON: Autor: 4 (Assaltante), Crime: 13, Grupo: Nulo, Local: Avenida Brasil.

## Exemplo de raciocínio 2
Texto: "Traficantes do CV mataram uma mulher na minha casa"
Raciocínio:
- Ação: Matar (Homicídio Doloso).
- Quem? "Traficantes do CV".
- Status mencionado? Sim (Traficante). Status vence Papel.
JSON: Autor: 3 (Traficante), Crime: 1, Grupo: Comando Vermelho.

## Exemplo de raciocínio 3
Texto: "Tiros ouvidos agora na Cidade de Deus."
Raciocínio:
- Ação: Tiros.
- Quem? Não se sabe quem atirou.
- Definição pelo Ato: Não há um "Atirador" na tabela, e tiros podem vir de qualquer lado.
JSON: Autor: 15 (Não Identificado), Crime: 41, Grupo: Nulo (ou Tráfico não identificado se inferido pelo local, mas Nulo é mais seguro se não citado).

Analise o texto abaixo e gere a lista classificada.
"""

prompt_classificacao = ChatPromptTemplate.from_messages([
    ("system", system_prompt_completo),
    ("user", "Texto para análise: {texto_input}")
])

from typing import List

def verificar_regras_negocio(lista: ListaDeEventos) -> List[str]:
    erros = []

    # ==============================================================================
    # 1. DEFINIÇÃO DE CONJUNTOS DE CRIMES (SETS)
    # ==============================================================================

    # Crimes que exigem DOLO (Vontade/Intenção)
    # Incompatíveis com Autor Culposo
    CRIMES_INCOMPATIVEIS_COM_CULPOSO = {
        # Vida
        TipoCrimeEnum.HOMICIDIO_DOLOSO,
        TipoCrimeEnum.LATROCINIO,
        TipoCrimeEnum.TENTATIVA_HOMICIDIO,
        TipoCrimeEnum.LESAO_CORPORAL_SEGUIDA_DE_MORTE,
        TipoCrimeEnum.LETALIDADE_VIOLENTA,
        # Dignidade Sexual
        TipoCrimeEnum.ESTUPRO,
        # Lesões
        TipoCrimeEnum.LESAO_CORPORAL_DOLOSA,
        # Roubos (todos)
        TipoCrimeEnum.ROUBO_TRANSEUNTE, TipoCrimeEnum.ROUBO_CELULAR,
        TipoCrimeEnum.ROUBO_EM_COLETIVO, TipoCrimeEnum.ROUBO_VEICULO,
        TipoCrimeEnum.ROUBO_CARGA, TipoCrimeEnum.ROUBO_COMERCIO,
        TipoCrimeEnum.ROUBO_RESIDENCIA, TipoCrimeEnum.ROUBO_BANCO,
        TipoCrimeEnum.ROUBO_CAIXA_ELETRONICO, TipoCrimeEnum.ROUBO_CONDUCAO_SAQUE,
        TipoCrimeEnum.ROUBO_APOS_SAQUE, TipoCrimeEnum.ROUBO_BICICLETA,
        TipoCrimeEnum.OUTROS_ROUBOS,
        # Patrimoniais Dolosos / Extorsão
        TipoCrimeEnum.EXTORSAO, TipoCrimeEnum.ESTELIONATO,
        TipoCrimeEnum.SEQUESTRO, TipoCrimeEnum.SEQUESTRO_RElampago,
        # Drogas
        TipoCrimeEnum.TRAFICO_DROGAS, TipoCrimeEnum.POSSE_DROGAS,
        # Outros
        TipoCrimeEnum.AMEACA, TipoCrimeEnum.ENCONTRO_CADAVER,
        TipoCrimeEnum.FURTO_VEICULOS, TipoCrimeEnum.FURTO_CELULAR # Furtos também são dolosos
    }

    # Crimes de SUBTRAÇÃO SEM VIOLÊNCIA (Furtos)
    # Incompatíveis com Assaltante (que implica violência)
    CRIMES_DE_FURTO = {
        TipoCrimeEnum.FURTO_VEICULOS,
        TipoCrimeEnum.FURTO_TRANSEUNTE,
        TipoCrimeEnum.FURTO_COLETIVO,
        TipoCrimeEnum.FURTO_CELULAR,
        TipoCrimeEnum.FURTO_BICICLETA,
        TipoCrimeEnum.OUTROS_FURTOS,
    }

    # Crimes VIOLENTOS ou com GRAVE AMEAÇA
    # Incompatíveis com Furtador (que age na surdina)
    CRIMES_VIOLENTOS_OU_GRAVES = {
        # Vida e Integridade Física
        TipoCrimeEnum.HOMICIDIO_DOLOSO, TipoCrimeEnum.LATROCINIO,
        TipoCrimeEnum.TENTATIVA_HOMICIDIO, TipoCrimeEnum.LESAO_CORPORAL_DOLOSA,
        TipoCrimeEnum.LESAO_CORPORAL_SEGUIDA_DE_MORTE,
        # Sexual
        TipoCrimeEnum.ESTUPRO,
        # Liberdade
        TipoCrimeEnum.SEQUESTRO, TipoCrimeEnum.SEQUESTRO_RElampago, TipoCrimeEnum.EXTORSAO,
        # Todos os Roubos
        TipoCrimeEnum.ROUBO_TRANSEUNTE, TipoCrimeEnum.ROUBO_CELULAR,
        TipoCrimeEnum.ROUBO_EM_COLETIVO, TipoCrimeEnum.ROUBO_VEICULO,
        TipoCrimeEnum.ROUBO_CARGA, TipoCrimeEnum.ROUBO_COMERCIO,
        TipoCrimeEnum.ROUBO_RESIDENCIA, TipoCrimeEnum.ROUBO_BANCO,
        TipoCrimeEnum.ROUBO_CAIXA_ELETRONICO, TipoCrimeEnum.ROUBO_CONDUCAO_SAQUE,
        TipoCrimeEnum.ROUBO_APOS_SAQUE, TipoCrimeEnum.ROUBO_BICICLETA,
        TipoCrimeEnum.OUTROS_ROUBOS,
        # Outros
        TipoCrimeEnum.TIROS, TipoCrimeEnum.POLICIAIS_MORTOS_EM_SERVICO
    }

    # ==============================================================================
    # 2. ITERAÇÃO E VALIDAÇÃO
    # ==============================================================================

    for i, evento in enumerate(lista.eventos):
        idx = i + 1
        eid = evento.id

        # REGRA 1 — Culpa × Dolo (regra ontológica central)
        if (
            evento.autor == TipoAutorEnum.AUTOR_CULPOSO
            and evento.crime in CRIMES_INCOMPATIVEIS_COM_CULPOSO
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Autor Culposo é logicamente incompatível com crime que exige dolo."
            )

        # REGRA 2 — Miliciano não pertence a facção do tráfico
        if (
            evento.autor == TipoAutorEnum.MILICIANO
            and evento.grupo in {
                "Comando Vermelho",
                "Terceiro Comando Puro",
                "Amigo dos Amigos",
                "Tráfico não identificado",
            }
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Miliciano é incompatível com grupo de facção do tráfico."
            )

        # REGRA 3 — Assaltante não comete Furto
        # Lógica: O rótulo 'Assaltante' implica modus operandi violento.
        if (
            evento.autor == TipoAutorEnum.ASSALTANTE
            and evento.crime in CRIMES_DE_FURTO
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Autor classificado como 'Assaltante' não pode cometer crime de 'Furto' (sem violência)."
            )

        # REGRA 4 — Furtador não ROUBA
        # Lógica: Se houve violência, o autor deixa de ser Furtador e vira Assaltante/Agressor.
        if (
            evento.autor == TipoAutorEnum.FURTADOR
            and evento.crime in {
                TipoCrimeEnum.ROUBO_TRANSEUNTE, TipoCrimeEnum.ROUBO_CELULAR,
                TipoCrimeEnum.ROUBO_EM_COLETIVO, TipoCrimeEnum.ROUBO_VEICULO,
                TipoCrimeEnum.ROUBO_CARGA, TipoCrimeEnum.ROUBO_COMERCIO,
                TipoCrimeEnum.ROUBO_RESIDENCIA, TipoCrimeEnum.ROUBO_BANCO,
                TipoCrimeEnum.ROUBO_CAIXA_ELETRONICO, TipoCrimeEnum.ROUBO_CONDUCAO_SAQUE,
                TipoCrimeEnum.ROUBO_APOS_SAQUE, TipoCrimeEnum.ROUBO_BICICLETA,
                TipoCrimeEnum.OUTROS_ROUBOS
            }
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Autor classificado como 'Furtador' não pode cometer crimes violentos (Roubo, Homicídio, etc)."
            )

        # REGRA 5 — Intervenção Policial é exclusiva de Agentes do Estado
        if (
            evento.crime == TipoCrimeEnum.MORTE_INTERVENCAO_POLICIAL
            and evento.autor not in {TipoAutorEnum.POLICIAL, TipoAutorEnum.MILICIANO}
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Crime 'Morte por Intervenção Policial' exige autor Policial ou Miliciano."
            )

        # REGRA 6 — Usuário não Trafica (naquele ato)
        if (
            evento.autor == TipoAutorEnum.USUARIO_DE_DROGAS
            and evento.crime == TipoCrimeEnum.TRAFICO_DROGAS
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Autor 'Usuário de Drogas' é incompatível com o crime de 'Tráfico de Drogas'."
            )

        # REGRA 7 — Crime 'Sem Crime' exige autor 'Sem Crime'
        if (
            evento.crime == TipoCrimeEnum.SEM_CRIME
            and evento.autor != TipoAutorEnum.SEM_CRIME
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Crime classificado como 'Sem Crime' exige autor 'Sem Crime'."
            )

        # REGRA 8 — Autor 'Sem Crime' não pode ter crime tipificado
        if (
            evento.autor == TipoAutorEnum.SEM_CRIME
            and evento.crime != TipoCrimeEnum.SEM_CRIME
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Autor 'Sem Crime' é incompatível com crime tipificado."
            )

        # REGRA 10 — Crimes culposos não se associam a grupos criminosos
        if (
            evento.autor == TipoAutorEnum.AUTOR_CULPOSO
            and evento.grupo != "Nulo"
        ):
            erros.append(
                f"Evento {idx} (ID {eid}): Crimes culposos são incompatíveis com associação a grupos criminosos."
            )

        if evento.autor == TipoAutorEnum.AUTOR_NAO_IDENTIFICADO:
            crimes_proibidos_para_nao_identificado = {
                # Todos os Homicídios e Lesões Dolosas (Deveria ser Homicida/Agressor)
                TipoCrimeEnum.HOMICIDIO_DOLOSO, TipoCrimeEnum.TENTATIVA_HOMICIDIO,
                TipoCrimeEnum.LESAO_CORPORAL_DOLOSA, TipoCrimeEnum.LESAO_CORPORAL_SEGUIDA_DE_MORTE,
                TipoCrimeEnum.LATROCINIO,
                
                # Todos os Roubos (Deveria ser Assaltante)
                TipoCrimeEnum.ROUBO_TRANSEUNTE, TipoCrimeEnum.ROUBO_CELULAR,
                TipoCrimeEnum.ROUBO_EM_COLETIVO, TipoCrimeEnum.ROUBO_VEICULO,
                TipoCrimeEnum.ROUBO_CARGA, TipoCrimeEnum.ROUBO_COMERCIO,
                TipoCrimeEnum.ROUBO_RESIDENCIA, TipoCrimeEnum.ROUBO_BANCO,
                TipoCrimeEnum.ROUBO_CAIXA_ELETRONICO, TipoCrimeEnum.ROUBO_CONDUCAO_SAQUE,
                TipoCrimeEnum.ROUBO_APOS_SAQUE, TipoCrimeEnum.ROUBO_BICICLETA,
                TipoCrimeEnum.OUTROS_ROUBOS,
                
                # Estupro (Deveria ser Estuprador)
                TipoCrimeEnum.ESTUPRO,
                
                # Sequestro/Extorsão
                TipoCrimeEnum.SEQUESTRO, TipoCrimeEnum.EXTORSAO, TipoCrimeEnum.SEQUESTRO_RElampago
            }
            
            if evento.crime in crimes_proibidos_para_nao_identificado:
                erros.append(
                    f"Evento {idx} (ID {eid}): Erro de Classificação. Para o crime '{evento.crime.name}', "
                    f"NÃO use 'Autor Não Identificado'. Use o papel correspondente (ex: Assaltante, Homicida, Estuprador) "
                    f"se o indivíduo não for conhecido."
                )

    return erros


chain_classificacao = prompt_classificacao | llm.with_structured_output(ListaDeEventos)

def node_classificador(state: GraphState):    
    msg_erro = state.get("erro_validacao")
    texto = state['texto_input']

    # Se houver erro anterior, injetamos no prompt
    if msg_erro:
        prompt_user = f"""
        O texto original é: "{texto}"
        
        Sua extração anterior conteve ERROS LÓGICOS GRAVES que precisam ser corrigidos:
        {msg_erro}
        
        Refaça a classificação corrigindo esses pontos. Mantenha o resto que estava certo.
        """
    else:
        # Fluxo normal
        prompt_user = f"Texto para análise: {texto}"
    prompt = ChatPromptTemplate.from_messages([
        ("system", system_prompt_completo),
        ("user", "{input}")
    ])
    
    chain = prompt | llm.with_structured_output(ListaDeEventos)
    
    try:
        res = chain.invoke({"input": prompt_user})
    except Exception as e:
        return {"erro_validacao": f"Erro de formato JSON: {str(e)}", "eventos_crimes": ListaDeEventos(eventos=[])}

    return {"eventos_crimes": res}

def node_validador(state: GraphState):    
    eventos = state['eventos_crimes']
    lista_erros = verificar_regras_negocio(eventos)
    
    tentativas = state.get("tentativas_validacao", 0) + 1
    
    if lista_erros:
        msg_consolidada = "\n".join(lista_erros)
        return {
            "erro_validacao": msg_consolidada,
            "tentativas_validacao": tentativas
        }
    else:
        return {
            "erro_validacao": None, # Limpa o erro
            "tentativas_validacao": tentativas
        }

def router_validacao(state: GraphState):
    erros = state.get("erro_validacao")
    tentativas = state.get("tentativas_validacao", 1)
    if erros and tentativas <= 3:
        return "retry"
    return "seguir"



#############################################################################################

# 3. Crie o Parser
llm_geo_agent = llm.bind_tools(tools_geo + [SubmeterLocalizacoes], tool_choice='required')

def run_geo_reasoning(state: GraphState):
    
    mensagens_existentes = state.get("messages", [])
    
    system_prompt_content = """
Você é um Motor de Geocodificação e Normalização de Endereços do Rio de Janeiro.
Sua função é converter descrições de texto em IDs de Bairro (Banco de Dados) e Logradouros oficiais (API).
Você deve fazer apenas chamadas de ferramenta (Tool Calls).

### SUAS FERRAMENTAS:
Você tem ferramentas à sua disposição

### ÁRVORE DE DECISÃO (Siga passo a passo para CADA item):

**CASO 0: LOCAL VAZIO OU NÃO INFORMADO**
*Ex: Input vazio, None, ou texto genérico sem local (ex: "crime ocorrido ontem").*
1. **Ação:** Não faça buscas.
2. **Resultado:** Defina `id_bairro_db = 0` e `logradouro_normalizado = None`.
3. **Próximo:** Vá para a Finalização.

---

**CASO A: LOCAL COMPOSTO (Logradouro/POI + Contexto de Bairro)**
*Ex: "Hospital Miguel Couto no Leblon", "Rua A em Madureira"*
1. **Busca:** Chame a API com o texto completo.
2. **Filtragem:** Analise o JSON retornado. Mantenha apenas os resultados onde o campo `suburb` ou `neighborhood` coincida com o bairro mencionado.
3. **Seleção:** Dentre os filtrados, pegue o que tiver o endereço (`road`) mais detalhado.
   - O `logradouro` final DEVE ser o valor do campo `road` da API.
4. **ID do Bairro:** Pegue o nome do bairro retornado pela API (campo `suburb`) e chame a busca de bairro para pegar o ID oficial.

---
2. **Desambiguação:** Se o comentário disser "eles atiraram", use a lista de **Autores da Publicação** para identificar quem são "eles".

**CASO B: LOCAL ÚNICO (Nome solto)**
*Ex: "Vila Kennedy", "Oswaldo Cruz", "Bar do Zé"*
1. **Triagem:** Primeiro, chame API.
2. **Análise do Resultado:**
   - **Se for BAIRRO:** (API retorna tipo `suburb`, `neighborhood` ou `place_rank` alto).
     - Logradouro deve ser `None` (Nulo).
     - Chame a busca de bairro com o nome para pegar o ID.
   - **Se for POI/RUA:** (API retorna campo `road` ou `amenity`).
     - Logradouro deve ser SOMENTE o campo `road` da API.
     - Bairro deve ser o campo `suburb` da API. Chame a busca de bairro com esse bairro para pegar o ID.
   - **Se NADA for encontrado:**
     - Tente variações fonéticas (Ex: Trocar 'V' por 'W', 'I' por 'Y', 'S' por 'Z' etc, remover ou adicionar acentos).
     - Repita a busca na API. Se falhar novamente, retorne ID=0 e Logradouro=None.

---

### REGRAS DE OURO (CRÍTICAS):
1. **HIERARQUIA DA VERDADE:**
   - O **ID do Bairro** deve vir SEMPRE da ferramenta de busca de bairro.
   - O **Nome do Logradouro** deve vir SEMPRE do campo `road` da ferramenta da API.

2. **BAIRRO NÃO TEM RUA:**
   - Se o local for classificado como Bairro, o `logradouro_normalizado` DEVE ser `null`. Jamais invente uma rua.

3. **ANTI-ALUCINAÇÃO:**
   - **PROIBIDO ESCREVER JSON OU "ARGUMENTS" NO TEXTO.**
   - Apenas dispare a ferramenta (Tool Call).

### FINALIZAÇÃO:
- Após resolver o ID e o Logradouro (ou null) para o item, passe para o próximo.
- Ao terminar a lista, chame `SubmeterLocalizacoes`.
"""
    system_msg = SystemMessage(content=system_prompt_content)

    # Lista temporária APENAS para enviar ao LLM nesta execução
    msgs_para_o_llm = [system_msg]
    
    # Lista de mensagens que serão SALVAS no estado ao final
    mensagens_a_salvar = []

    # 1. Lógica de Entrada (Primeira vez)
    if not mensagens_existentes:
        lista_str = "\n".join([f"- ID: {e.id} | LOCAL: '{e.local}'" for e in state['eventos_crimes'].eventos])
        
        msg_inicial = HumanMessage(content=f"LISTA DE ALVOS: {lista_str}")
        
        msgs_para_o_llm.append(msg_inicial)
        mensagens_a_salvar.append(msg_inicial)

    else:
        # 2. Lógica de Loop (Retomada)
        msgs_para_o_llm.extend(mensagens_existentes)
        
        # --- CORREÇÃO DO LOOP ---
        last_msg = mensagens_existentes[-1]
        
        if isinstance(last_msg, AIMessage) and not last_msg.tool_calls:
            if '"arguments":' in last_msg.content or "{" in last_msg.content:
                msg_correcao = HumanMessage(content="""
                ERRO TÉCNICO: Você escreveu os argumentos da ferramenta no TEXTO da resposta. 
                ISSO É PROIBIDO.
                NÃO escreva JSON ou "arguments".
                USE A INTERFACE NATIVA DE TOOL CALLS.
                Tente novamente agora, apenas chamando a função.
                """)
                # IMPORTANTE: Adicionamos apenas ao contexto do LLM, 
                # NÃO adicionamos a 'mensagens_a_salvar' se quisermos que a bronca seja efêmera.
                # Se quiser que fique no histórico, adicione a 'mensagens_a_salvar' também.
                msgs_para_o_llm.append(msg_correcao)

    # 3. Invoca o LLM
    try:
        response = llm_geo_agent.invoke(msgs_para_o_llm)
    except Exception as e:
        print(f"Erro no invoke: {e}")
        response = AIMessage(content="Ocorreu um erro interno. Vou tentar novamente.")

    # Adiciona a resposta do LLM à lista de salvamento
    mensagens_a_salvar.append(response)
    
    # Retorna APENAS as novas mensagens para o LangGraph fazer o append no estado
    return {"messages": mensagens_a_salvar}


def router_geo(state: GraphState):
    """
    Router do agente geográfico.
    Decide o próximo nó com base na última mensagem do LLM.
    """
    messages = state.get("messages", [])
    
    # 1. Segurança Básica
    if not messages:
        return "geo_agent"

    last_msg = messages[-1]

    # 2. Verifica se a mensagem é realmente do Assistente (AIMessage)
    # Se for ToolMessage, HumanMessage ou SystemMessage, algo saiu da ordem.
    # Mandamos voltar para o agente pensar.
    if not isinstance(last_msg, AIMessage):
        return "geo_agent"

    # 3. Verifica se tem Tool Calls
    # Se a lista for vazia ou None -> Agente falou texto, manda ele pensar de novo (ou força tool)
    if not last_msg.tool_calls:
        return "geo_agent"

    # 4. Agora é seguro acessar o índice [0]
    tool_name = last_msg.tool_calls[0]["name"]
    if tool_name == "SubmeterLocalizacoes":
        return "normalizacao"
    else:
        return "tools_geo"

def router_check_eventos(state: GraphState) -> Literal["geo_agent", "normalizacao"]:
    """
    Verifica se há eventos para processar ANTES de chamar o agente.
    Economiza tokens se a lista estiver vazia.
    """    
    # Recupera o objeto ListaDeEventos
    eventos_obj = state.get("eventos_crimes")
    
    # Lógica de proteção
    # 1. Se for None
    # 2. Se a lista interna 'eventos' estiver vazia
    if not eventos_obj or not eventos_obj.eventos:
        return "normalizacao" # Pula o agente geográfico
    return "geo_agent"


# --- Nó Auxiliar para processar a saída final ---
def node_normalizacao(state: GraphState):
    
    messages = state.get("messages", [])
    
    # 1. Se não há mensagens (Router de pré-check pulou tudo), retorna vazio
    if not messages:
        return {"eventos_finais": []}
    
    last_msg = messages[-1]
    
    # --- CORREÇÃO DO ERRO ---
    # Verificamos se a mensagem é realmente do Assistente (AI).
    # Se for ToolMessage (resultado de ferramenta) ou HumanMessage, ignoramos.
    if not isinstance(last_msg, AIMessage):
        # Se chegou aqui com uma ToolMessage, significa que o fluxo foi interrompido 
        # ou desviado antes do Agente finalizar. Retornamos vazio por segurança.
        return {"eventos_finais": []}
    
    # Validação de Segurança: Se não tem tool_calls ou não é a tool certa
    if not last_msg.tool_calls or last_msg.tool_calls[0]["name"] != "SubmeterLocalizacoes":
        return {"eventos_finais": []}

    # 2. Extrai os dados geográficos
    try:
        args = last_msg.tool_calls[0]["args"]
        resultados_geo = args.get("resultados", [])
    except Exception:
        return {"eventos_finais": []}
    
    # 3. Cria um Mapa (Hash Map)
    mapa_geo = {item['id_endereco_original']: item for item in resultados_geo}
    
    lista_final = []
    
    # Proteção para recuperar eventos
    eventos_obj = state.get('eventos_crimes')
    lista_eventos = eventos_obj.eventos if eventos_obj else []

    # 4. Itera sobre a lista ORIGINAL
    for evento in lista_eventos:
        geo_data = mapa_geo.get(evento.id)
        
        bairro_id_final = 0
        logradouro_final = None
        
        if geo_data:
            bairro_id_final = geo_data.get('id_bairro_db', 0)
            logradouro_final = geo_data.get('logradouro_normalizado') 
            
        # 5. Fusão (Merge)
        evt_enriquecido = EventoEnriquecido(
            **evento.model_dump(),
            bairro_id=bairro_id_final,
            logradouro=logradouro_final 
        )
        
        lista_final.append(evt_enriquecido)
        
    return {"eventos_finais": lista_final}

tool_node = ToolNode(tools=tools_geo + [SubmeterLocalizacoes])

###############################################################################################

def estruturar_resposta_final(state: GraphState) -> dict:
    """
    Processa o estado final e retorna uma LISTA DE DICIONÁRIOS Python.
    Robustez aumentada para aceitar JSON válido (aspas duplas) e 'Python Dicts' (aspas simples).
    """
    
    # 1. Recupera os eventos originais
    lista_eventos_originais = state['eventos_crimes'].eventos or []
    
    # 2. Recupera a string bruta
    last_message_content = state['messages'][-1].content
    
    dados_geo = []
    
    # --- ESTRATÉGIA A: Tentar encontrar uma lista [...] ---
    match_list = re.search(r"\[.*\]", last_message_content, re.DOTALL)
    
    parsed = False
    
    if match_list:
        content_str = match_list.group(0)
        
        # Tentativa 1: JSON Padrão (Aspas Duplas)
        try:
            dados_geo = json.loads(content_str)
            parsed = True
        except json.JSONDecodeError:
            # Tentativa 2: Sintaxe Python/Mista (Aspas Simples + null)
            try:
                # O ast.literal_eval falha com 'null', 'true', 'false' (que são JSON).
                # Convertemos para Python: None, True, False
                python_str = content_str.replace('null', 'None').replace('true', 'True').replace('false', 'False')
                dados_geo = ast.literal_eval(python_str)
                parsed = True
            except (ValueError, SyntaxError):
                pass # Falhou nas duas, tenta Estratégia B

    # --- ESTRATÉGIA B: Tentar encontrar objetos soltos {...} ---
    if not parsed:
        matches_objects = re.findall(r"\{.*?\}", last_message_content, re.DOTALL)
        
        temp_list = []
        for obj_str in matches_objects:
            # Tenta JSON puro
            try:
                obj_json = json.loads(obj_str)
                temp_list.append(obj_json)
                continue
            except json.JSONDecodeError:
                pass
            
            # Tenta Python Dict misto
            try:
                python_str = obj_str.replace('null', 'None').replace('true', 'True').replace('false', 'False')
                obj_py = ast.literal_eval(python_str)
                temp_list.append(obj_py)
            except (ValueError, SyntaxError):
                continue

        if temp_list:
            dados_geo = temp_list
            parsed = True

    if isinstance(dados_geo, dict):
        dados_geo = [dados_geo]

    # 3. Merge (Mantido igual)
    # Usa str() no ID para garantir match mesmo se um for int e o outro str
    mapa_geo = {str(item.get('id_endereco')): item for item in dados_geo}

    resultado_final = []

    for evento in lista_eventos_originais:
        evento_dict = evento.model_dump()
        id_busca = str(evento.id) 
        
        geo_match = mapa_geo.get(id_busca)
        
        if geo_match:
            evento_dict['bairro_id'] = geo_match.get('id')
            evento_dict['local_normalizado'] = geo_match.get('logradouro')
        else:
            evento_dict['bairro_id'] = None
            evento_dict['local_normalizado'] = "Não identificado"
        
        evento_dict.pop('id', None)
        resultado_final.append(evento_dict)

    return {'resposta_final': resultado_final}

prompt_classificador = ChatPromptTemplate.from_messages([
    ("system", """Você é um triador de denúncias de segurança pública.
    Sua única função é dizer se o texto relata um fato criminoso/violento ou não.
    
    CRITÉRIOS PARA 'Sim':
    - Relatos de roubos, tiros, agressões, operações policiais, tráfico, milícia.
    - Fatos ocorridos (ex: "roubaram meu carro", "tiroteio na praça").
    
    CRITÉRIOS PARA 'Não':
    - Opiniões políticas (ex: "o governador é ruim").
    - Mensagens religiosas/apoio (ex: "Deus proteja a todos").
    - Reclamações de infraestrutura (ex: "buraco na rua").
    - Perguntas ou comentários vagos sem descrição de evento.
    - desejos, como "tem que matar"
    
    Analise o texto abaixo:"""),
    ("user", "{texto_input}")
])

def no_classificador_crime(state):
    texto = state['texto_input']
    classificador = prompt_classificador | llm.with_structured_output(HouveCrime)
    try:
        resultado = classificador.invoke({"texto_input": texto})
        decisao = resultado.ha_crime
    except Exception as e:
        decisao = "Não"
        
    return {"classificacao_binaria": decisao}


def roteador_crime(state):
    decisao = state.get("classificacao_binaria")
    if decisao == "Sim":
        return "extrair_detalhes"
    else:
        return '__end__'

def router_validacao_e_check(state: GraphState) -> Literal["retry", "normalizacao", "geo_agent"]:
    """
    1. Verifica se houve erro de validação.
    2. Se validou, verifica se a lista está vazia.
    3. Se tem itens, manda para o agente geográfico.
    """
    
    # 1. Prioridade: Erro de Validação (JSON quebrado ou lógica inválida)
    if state.get("erro_validacao"):
        return "retry"
    
    # 2. Se passou na validação, checamos se tem conteúdo
    eventos_obj = state.get("eventos_crimes")
    
    if not eventos_obj or not eventos_obj.eventos:
        return "normalizacao" # Atalho para o fim
    
    # 3. Tudo certo e com itens para processar
    return "geo_agent"

######################################################################################################3
system_prompt_triagem_comentario = """
Você é um sistema de triagem de comentários sobre crimes.
Sua missão é identificar se o COMENTÁRIO traz informações novas ou confirmações sobre o EVENTO ORIGINAL.

CONTEXTO DO POST ORIGINAL:
{contexto_evento}

CRITÉRIOS PARA APROVAR (True):
- O comentário confirma o crime citado no post.
- O comentário traz novos detalhes (ex: direção de fuga, armas usadas, quantidade de envolvidos).
- O comentário identifica autores ou vítimas não citados no post original.

CRITÉRIOS PARA REJEITAR (False):
- Reações puramente emocionais ou religiosas ("Amém", "Que horror").
- Discussões paralelas que fogem do crime.
- Spam ou comentários vazios.

Se o comentário for vago, mas puder ser uma atualização do evento original, APROVE.

Comentário: {texto_input}
"""

triagem_prompt = PromptTemplate(
    template=system_prompt_triagem_comentario,
    input_variables=["contexto_evento"]  # variáveis que você vai passar dinamicamente
)

triagem_chain_comentario = triagem_prompt | llm.with_structured_output(ClassificacaoRelevancia)

def node_triagem_comentario(state: GraphStateComentario):
    # Criamos um resumo do contexto herdado para a IA
    contexto_herdado = f"""
    Local: {state.get('contexto_local', 'Não informado')}
    Crime: {state.get('contexto_crimes', 'Não informado')}
    Autores: {state.get('contexto_autores', 'Não informado')}
    """
    
    texto_comentario = state['texto_input']
    
    try:
        # Passamos o contexto para o prompt
        resultado = triagem_chain_comentario.invoke({
            "contexto_evento": contexto_herdado,
            "texto_input": texto_comentario
        })
        return {"eh_relevante": resultado.eh_relevante}
    except Exception:
        return {"eh_relevante": False}
    

system_prompt_completo_comentario = system_prompt_completo + """\nUtilize o contexto abaixo para classificar o comentário.
O comentário herda os locais e crimes do contexto."""

chain_classificacao = prompt_classificacao | llm.with_structured_output(ListaDeEventos)

def node_classificador_comentario(state: GraphStateComentario):    
    msg_erro = state.get("erro_validacao")
    texto = state['texto_input']

    contexto_herdado = f"""
        Local: {state.get('contexto_local', 'Não informado')}
        Crime: {state.get('contexto_crimes', 'Não informado')}
        Autores: {state.get('contexto_autores', 'Não informado')}
    """

    # Se houver erro anterior, injetamos no prompt
    if msg_erro:
        prompt_user = f"""
        O texto original é: "{texto}"
        
        Sua extração anterior conteve ERROS LÓGICOS GRAVES que precisam ser corrigidos:
        {msg_erro}
        
        Refaça a classificação corrigindo esses pontos. Mantenha o resto que estava certo.
        """
    else:
        prompt_user = f"Texto para análise: {texto}"
    prompt = ChatPromptTemplate.from_messages([
        ("system", system_prompt_completo_comentario),
        ("user", f"Contexto: {contexto_herdado}\n\nCOMENTÁRIO:\n{texto}")
    ])
    
    chain = prompt | llm.with_structured_output(ListaDeEventos)
    
    try:
        res = chain.invoke({"input": prompt_user})
    except Exception as e:
        return {"erro_validacao": f"Erro de formato JSON: {str(e)}", "eventos_crimes": ListaDeEventos(eventos=[])}

    return {"eventos_crimes": res}




