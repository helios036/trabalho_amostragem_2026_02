/* =========================================================================
   TRABALHO DE AMOSTRAGEM
   Base: Intenção de voto - Pavilhões (Brasília)

   PLANO AMOSTRAL DE CAMPO: Amostragem Sistemática, com intervalo K=5
   (a cada 5 pessoas que passavam pelo pavilhão, 1 era abordada, com
   início aleatório sorteado entre a 1ª e a 5ª pessoa da sequência).
   Amostra nominal: n = 400, de uma população desconhecida/grande
   (sem correção de população finita - fpc).

   Para fins de cálculo de variância/erro-padrão das estimativas, a
   amostragem sistemática é tratada de forma equivalente à AAS - essa é
   a prática padrão quando não há suspeita de periodicidade/tendência
   na ordem de chegada das pessoas no pavilhão (não há motivo para
   acreditar que a cada 5ª pessoa exista um padrão sistemático de
   intenção de voto). Essa suposição deve ser declarada no relatório.

   Objetivo: estimar as proporções de intenção de voto na população,
   com variância, margem de erro, intervalo de confiança, e avaliar
   o efeito da não-resposta sobre a precisão das estimativas.
   ========================================================================= */

options validvarname=any;   /* permite nomes de coluna com espaço/acento no import */

%let n_nominal = 400;   /* tamanho da amostra definido para a pesquisa */
%let K         = 5;     /* intervalo da amostragem sistemática em campo */

/* Tamanho do eleitorado do Distrito Federal (população de referência para
   Presidente/Governador), conforme TRE-DF, julho/2026: "Distrito Federal
   ultrapassa 2,56 milhões de eleitores e registra 94,4% do eleitorado
   apto com biometria". Usado apenas para calcular explicitamente o fpc
   (correção de população finita) no PROC SURVEYFREQ - com n≈391 e
   N=2.562.037, f=n/N≈0,000153 e fpc=sqrt(1-f)≈0,99992, ou seja, o efeito
   numérico é desprezível (não altera as estimativas em casas decimais
   relevantes). Mantém-se, portanto, a leitura de população "grande" do
   cabeçalho deste script - este N apenas formaliza/comprova essa escolha
   com uma fonte, não torna a amostra representativa de todo o DF (a
   coleta não foi um sorteio probabilístico do eleitorado do DF como um
   todo, e sim uma amostragem sistemática de visitantes de dois pavilhões
   específicos - ver limitações no relatório).
   Fonte: https://www.tre-df.jus.br/comunicacao/noticias/2026/Julho/distrito-federal-ultrapassa-2-56-milhoes-de-eleitores-e-registra-94-4-do-eleitorado-apto-com-biometria-1 */
%let N_DF = 2562037;

/* -------------------------------------------------------------------------
   SALVAR GRÁFICOS COMO .PNG
   Ajuste "outpath" para o caminho da pasta "imagens" dentro do seu Files
   (Home) no SAS Studio — mesmo tipo de ajuste já feito no datafile= da
   PROC IMPORT (o SAS Studio roda num servidor Linux, não no seu PC).
   ------------------------------------------------------------------------- */
%let outpath = /home/helios_0190/imagens;

ods listing gpath="&outpath." image_dpi=200;
ods graphics on / width=800px height=500px imagefmt=png reset=all;

/* -------------------------------------------------------------------------
   1. IMPORTAÇÃO DA AMOSTRA
   ------------------------------------------------------------------------- */
proc import out=amostra_raw
    datafile="/home/helios_0190/intenções_de_voto_pavilhões_v2.xlsx"
    dbms=xlsx replace;
    getnames=yes;
run;

/* -------------------------------------------------------------------------
   2. PREPARAÇÃO
      - renomeia colunas
      - remove linhas totalmente vazias (artefato da tabela do Excel)
      - cria identificador único
      - NESTA VERSÃO (v2) da planilha, a não-resposta em Presidente/
        Governador/Faixa etária/Faixa de renda aparece como célula
        genuinamente em branco (136 respondentes, 34%) - não há mais o
        texto "Sem resposta" em Presidente/Governador. Em Faixa etária/
        Faixa de renda, "Sem resposta" ainda aparece como opção
        explícita (5 e 27 casos) ao lado de células em branco (136) -
        as duas coisas são unificadas sob o mesmo rótulo "Sem resposta"
        abaixo, pois ali é uma opção legítima do perfil, não recusa.
   ------------------------------------------------------------------------- */
data amostra;
    set amostra_raw;
    rename
        'Sexo'n                     = sexo
        'Faixa etária'n              = faixa_etaria
        'Faixa de renda familiar'n   = faixa_renda
        'Presidente'n                = presidente
        'Governador'n                = governador
        'Turno'n                     = turno;
run;

data amostra;
    set amostra;
    if missing(Timestamp) then delete;   /* descarta linhas vazias (artefato) */
    id = _n_;
    /* corrige espaço em branco inicial em "Samara Martins (11)" (artefato de
       digitação no Excel), que fazia essa resposta contar como categoria
       separada nas tabelas de frequência e ficar sem cor no gráfico */
    presidente = strip(presidente);
    governador = strip(governador);
    /* Faixa etária/renda: célula em branco = mesma coisa que a opção
       explícita "Sem resposta" (ambas significam que a pessoa não
       informou essa variável de perfil) - unifica num só rótulo. */
    if missing(faixa_etaria) then faixa_etaria = 'Sem resposta';
    if missing(faixa_renda)  then faixa_renda  = 'Sem resposta';
    /* Presidente/Governador: célula em branco é recusa à pergunta de
       voto - mantém como missing (não-resposta), diferente de "Não
       sei/não quero responder", que é resposta engajada e válida.
       Nesta versão (v2) da planilha não existe mais o texto "Sem
       resposta" nessas duas colunas (só célula em branco), mas a linha
       abaixo é mantida por segurança caso o texto reapareça numa
       futura atualização da planilha. */
    if presidente = 'Sem resposta' then presidente = '';
    if governador = 'Sem resposta' then governador = '';
run;

proc contents data=amostra varnum; run;

/* -------------------------------------------------------------------------
   2.1 VARIÁVEIS ORDENADAS (para os gráficos seguirem um critério lógico,
       em vez da ordem alfabética padrão): Turno em ordem cronológica,
       Faixa de Renda e Faixa Etária em ordem crescente, com "Sem resposta"
       sempre na primeira posição. O FORMAT mantém o texto original visível
       nos eixos/tabelas, só a ordenação interna (numérica) muda.
   ------------------------------------------------------------------------- */
proc format;
    value turnofmt  1='Manhã' 2='Tarde' 3='Noite';
    value rendafmt  0='Sem resposta' 1='até R$ 1.000' 2='R$ 1.000 a R$ 2.000'
                    3='R$ 2.000 a R$ 5.000' 4='R$ 5.000 a R$ 10.000' 5='Mais de R$ 10.000';
    value etarfmt   0='Sem resposta' 1='até 18 anos' 2='19 a 24 anos' 3='25 a 29 anos'
                    4='30 a 34 anos' 5='35 a 39 anos' 6='40 a 44 anos' 7='Acima de 44 anos';
run;

data amostra;
    set amostra;

    select (turno);
        when ('Manhã') turno_ord = 1;
        when ('Tarde') turno_ord = 2;
        when ('Noite') turno_ord = 3;
        otherwise turno_ord = .;
    end;

    select (faixa_renda);
        when ('Sem resposta')         renda_ord = 0;
        when ('até R$ 1.000')         renda_ord = 1;
        when ('R$ 1.000 a R$ 2.000')  renda_ord = 2;
        when ('R$ 2.000 a R$ 5.000')  renda_ord = 3;
        when ('R$ 5.000 a R$ 10.000') renda_ord = 4;
        when ('Mais de R$ 10.000')    renda_ord = 5;
        otherwise renda_ord = .;
    end;

    select (faixa_etaria);
        when ('Sem resposta')     etaria_ord = 0;
        when ('até 18 anos')      etaria_ord = 1;
        when ('19 a 24 anos')     etaria_ord = 2;
        when ('25 a 29 anos')     etaria_ord = 3;
        when ('30 a 34 anos')     etaria_ord = 4;
        when ('35 a 39 anos')     etaria_ord = 5;
        when ('40 a 44 anos')     etaria_ord = 6;
        when ('Acima de 44 anos') etaria_ord = 7;
        otherwise etaria_ord = .;
    end;

    format turno_ord turnofmt. renda_ord rendafmt. etaria_ord etarfmt.;
run;

/* -------------------------------------------------------------------------
   2.2 MÉTODO: JUSTIFICATIVA DO TAMANHO DA AMOSTRA (engenharia reversa)
       Dado um erro admissível, qual seria o n necessário? Usa-se a forma
       simplificada n0 = Z² * p*(1-p) / e², com Z≈2 (aprox. de 95% de
       confiança) e p=0,5 (cenário de pior caso, variância máxima):

            n0 = 2² * 0,5*(1-0,5) / e² = 1 / e²

       Com e=5%, n0 = 1/0,05² = 400 - bate exatamente com o n coletado.
   ------------------------------------------------------------------------- */
data _null_;
    Z = 2;         /* aproximação usual para 95% de confiança */
    p = 0.5;       /* cenário de pior caso (variância máxima) */
    e = 0.05;      /* margem de erro admitida: 5 pontos percentuais */

    n0 = (Z**2 * p*(1-p)) / (e**2);   /* = 1/e² */

    put "---- Engenharia reversa do tamanho da amostra ----";
    put "Erro admitido: " e " | Confiança: ~95% (Z=" Z ") | p=0,5 (pior caso)";
    put "n necessário (n0 = 1/e²): " n0 best6.;
    put "n efetivamente coletado em campo: &n_nominal.";
    put "Plano de seleção em campo: sistemática, K=&K. (a cada &K.ª pessoa abordada)";
run;

/* -------------------------------------------------------------------------
   3. PERFIL DA AMOSTRA (estatísticas descritivas)
   ------------------------------------------------------------------------- */
title "Perfil da amostra (n nominal = &n_nominal.)";
proc freq data=amostra;
    tables sexo etaria_ord renda_ord turno_ord / nocum;
run;
title;

ods graphics / imagename="perfil_sexo";
title "Distribuição por Sexo";
proc sgplot data=amostra;
    vbar sexo / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Sexo";
run;
title;

ods graphics / imagename="perfil_etaria";
title "Distribuição por Faixa Etária";
proc sgplot data=amostra;
    vbar etaria_ord / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Faixa etária" fitpolicy=rotate;
run;
title;

ods graphics / imagename="perfil_renda";
title "Distribuição por Faixa de Renda Familiar";
proc sgplot data=amostra;
    vbar renda_ord / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Faixa de renda" fitpolicy=rotate;
run;
title;

ods graphics / imagename="perfil_turno";
title "Distribuição por Turno de Coleta";
proc sgplot data=amostra;
    vbar turno_ord / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Turno";
run;
title;

/* -------------------------------------------------------------------------
   4. NÃO-RESPOSTA (item non-response)
      Quantifica quantos respondentes recusaram responder Presidente/
      Governador - isso inclui tanto quem ficou literalmente em branco
      quanto quem marcou "Sem resposta" (ambos já viram missing() na
      seção 2, ver comentário lá), diferente da categoria "Não sei/Não
      quero responder", que é uma resposta válida e engajada (a pessoa
      respondeu, só não quis/soube nomear um candidato). Também verifica
      se a não-resposta se distribui igualmente entre os sexos (checagem
      de não-resposta diferencial, que pode indicar viés).
   ------------------------------------------------------------------------- */
data amostra;
    set amostra;
    resp_presidente = ifc(missing(presidente), 'Nao respondeu', 'Respondeu');
    resp_governador = ifc(missing(governador), 'Nao respondeu', 'Respondeu');
run;

title "Taxa de não-resposta - Presidente e Governador";
proc freq data=amostra;
    tables resp_presidente resp_governador / nocum;
run;

title "Não-resposta por Sexo (checagem de não-resposta diferencial)";
proc freq data=amostra;
    tables sexo*resp_presidente sexo*resp_governador / nocol nopercent;
run;
title;

ods graphics / imagename="naoresposta_presidente";
title "Taxa de resposta - Presidente";
proc sgplot data=amostra;
    vbar resp_presidente / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label=" ";
run;
title;

ods graphics / imagename="naoresposta_governador";
title "Taxa de resposta - Governador";
proc sgplot data=amostra;
    vbar resp_governador / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label=" ";
run;
title;

ods graphics / imagename="naoresposta_sexo_presidente";
title "Não-resposta por Sexo - Presidente";
proc sgplot data=amostra;
    vbar sexo / group=resp_presidente groupdisplay=cluster stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Sexo";
run;
title;

data _null_;
    set amostra end=eof;
    retain n_miss_pres 0 n_miss_gov 0;
    if missing(presidente) then n_miss_pres + 1;
    if missing(governador) then n_miss_gov + 1;
    if eof then do;
        n_valid_pres = &n_nominal. - n_miss_pres;
        n_valid_gov  = &n_nominal. - n_miss_gov;
        call symputx('n_miss_pres', n_miss_pres);
        call symputx('n_miss_gov', n_miss_gov);
        call symputx('n_valid_pres', n_valid_pres);
        call symputx('n_valid_gov', n_valid_gov);

        put "n nominal da amostra: &n_nominal.";
        put "Não-resposta Presidente: " n_miss_pres " (" ((n_miss_pres/&n_nominal.)*100) 4.1 "%)";
        put "Não-resposta Governador: " n_miss_gov " (" ((n_miss_gov/&n_nominal.)*100) 4.1 "%)";
        put "n válido p/ Presidente: " n_valid_pres;
        put "n válido p/ Governador: " n_valid_gov;
    end;
run;

/* -------------------------------------------------------------------------
   5. MARGEM DE ERRO: NOMINAL (n=400) x EFETIVA (descontando não-resposta)
      Como a população é desconhecida/grande, não há correção de população
      finita (fpc). Cenário de pior caso (p=0,5) para a margem de erro,
      usando o percentil t (TINV, df=n-1) em vez de Z fixo - mesma
      convenção adotada pelo professor em todas as aulas (aula3/4/5.sas):

           e = t(0,975; n-1) * sqrt( p*(1-p) / n )

      A não-resposta reduz o n efetivo de cada pergunta, o que AUMENTA
      a margem de erro em relação ao n nominal da amostra coletada.
   ------------------------------------------------------------------------- */
data _null_;
    p = 0.5;       /* cenário de variância máxima */

    t_nominal = tinv(0.975, &n_nominal. - 1);
    t_pres    = tinv(0.975, &n_valid_pres. - 1);
    t_gov     = tinv(0.975, &n_valid_gov. - 1);

    e_nominal = t_nominal * sqrt( p*(1-p) / &n_nominal. );
    e_pres    = t_pres    * sqrt( p*(1-p) / &n_valid_pres. );
    e_gov     = t_gov     * sqrt( p*(1-p) / &n_valid_gov. );

    put "Margem de erro c/ n nominal (&n_nominal.): " e_nominal best6.;
    put "Margem de erro efetiva - Presidente (n=&n_valid_pres.): " e_pres best6.;
    put "Margem de erro efetiva - Governador (n=&n_valid_gov.): " e_gov best6.;
run;

/* -------------------------------------------------------------------------
   6. VARIÂNCIA DAS ESTIMATIVAS (cálculo explícito pela fórmula)
      Para cada candidato: p_hat = count/n ; Var(p_hat) = p_hat*(1-p_hat)/(n-1)
      (estimador não-viesado de Cochran, população infinita/sem fpc - ver
      Seção 2.2 do relatório). O IC usa o percentil t (TINV, df=n-1), não
      Z fixo - mesma convenção do professor em aula3/4/5.sas. Serve para
      conferir "na mão" os desvios-padrão/IC que o PROC SURVEYFREQ calcula
      na seção 7.
   ------------------------------------------------------------------------- */
proc freq data=amostra noprint;
    tables presidente / out=freq_pres (where=(not missing(presidente)));
    tables governador / out=freq_gov  (where=(not missing(governador)));
run;

data var_pres;
    set freq_pres;
    n      = &n_valid_pres.;
    p_hat  = count / n;
    var_p  = p_hat*(1-p_hat) / (n-1);
    se_p   = sqrt(var_p);
    tcrit  = tinv(0.975, n-1);
    ic_li  = max(0, p_hat - tcrit*se_p);
    ic_ls  = min(1, p_hat + tcrit*se_p);
run;

data var_gov;
    set freq_gov;
    n      = &n_valid_gov.;
    p_hat  = count / n;
    var_p  = p_hat*(1-p_hat) / (n-1);
    se_p   = sqrt(var_p);
    tcrit  = tinv(0.975, n-1);
    ic_li  = max(0, p_hat - tcrit*se_p);
    ic_ls  = min(1, p_hat + tcrit*se_p);
run;

title "Variância e IC calculados manualmente - Presidente";
proc print data=var_pres noobs;
    var presidente count p_hat var_p se_p ic_li ic_ls;
run;

title "Variância e IC calculados manualmente - Governador";
proc print data=var_gov noobs;
    var governador count p_hat var_p se_p ic_li ic_ls;
run;
title;

/* -------------------------------------------------------------------------
   6.5 GRUPO "OUTROS" (candidatos com menos de 1% dos votos válidos)
       Consolida, em cada cargo, todo candidato cuja contagem represente
       menos de 1% de n_valido - isso inclui Romeu Zema (8), que tem cor
       própria definida na paleta (seção 6.7) mas apenas 1 voto (0,29%):
       por decisão explícita, o critério de 1% é aplicado sem exceção.
       Branco, Nulo e "Não sei/não quero responder" NUNCA entram em
       "Outros" (não são candidatos) - na prática, de toda forma, todos
       ficam acima de 1% nos dois cargos. "Sem resposta" não entra na
       conta nem nessa lista porque agora é tratada como não-resposta
       (missing), não como categoria de voto (seção 2.2). O formato é
       construído via lookup em hash object a partir das contagens já
       calculadas em freq_pres/freq_gov (seção 6), então se recalcula
       sozinho a cada nova rodada (se os votos mudarem, quem entra em
       "Outros" também pode mudar). Esse agrupamento vale só para os
       GRÁFICOS (seções 7 e 8.3) - as tabelas (PROC SURVEYFREQ, PROC
       PRINT) continuam com o detalhamento candidato a candidato.
       (OBS: a primeira versão usava PROC FORMAT/CNTLIN, mas o hash
       object evita qualquer ambiguidade de nome/formato na aplicação.)
   ------------------------------------------------------------------------- */
data amostra;
    set amostra;
    length presidente_grp governador_grp $40;   /* evita truncar p/ 6 chars ('Outros') */
    if _n_ = 1 then do;
        declare hash hpres(dataset: 'freq_pres(rename=(count=count_pres))');
        hpres.defineKey('presidente');
        hpres.defineData('count_pres');
        hpres.defineDone();
        declare hash hgov(dataset: 'freq_gov(rename=(count=count_gov))');
        hgov.defineKey('governador');
        hgov.defineData('count_gov');
        hgov.defineDone();
        call missing(count_pres, count_gov);
    end;

    if hpres.find() = 0
       and (count_pres / &n_valid_pres.) < 0.01
       and presidente not in ('Branco (13)', 'Nulo (14)',
             'Não sei/não quero responder (15)')
        then presidente_grp = 'Outros';
        else presidente_grp = presidente;

    if hgov.find() = 0
       and (count_gov / &n_valid_gov.) < 0.01
       and governador not in ('Branco (11)', 'Nulo (12)',
             'Não sei / Não quero responder (13)')
        then governador_grp = 'Outros';
        else governador_grp = governador;

    drop count_pres count_gov;
run;

/* -------------------------------------------------------------------------
   6.6 VARIÂNCIA DO GRUPO (para o gráfico de IC da seção 7, já com
       candidatos minoritários consolidados em "Outros") - mesma fórmula
       e critério da seção 6, agora sobre presidente_grp/governador_grp.
   ------------------------------------------------------------------------- */
proc freq data=amostra noprint;
    tables presidente_grp / out=freq_pres_grp (where=(not missing(presidente_grp)));
    tables governador_grp / out=freq_gov_grp  (where=(not missing(governador_grp)));
run;

data var_pres_grp;
    set freq_pres_grp;
    n      = &n_valid_pres.;
    p_hat  = count / n;
    var_p  = p_hat*(1-p_hat) / (n-1);
    se_p   = sqrt(var_p);
    tcrit  = tinv(0.975, n-1);
    ic_li  = max(0, p_hat - tcrit*se_p);
    ic_ls  = min(1, p_hat + tcrit*se_p);
    pct    = p_hat*100;
    li_pct = ic_li*100;
    ls_pct = ic_ls*100;
run;

data var_gov_grp;
    set freq_gov_grp;
    n      = &n_valid_gov.;
    p_hat  = count / n;
    var_p  = p_hat*(1-p_hat) / (n-1);
    se_p   = sqrt(var_p);
    tcrit  = tinv(0.975, n-1);
    ic_li  = max(0, p_hat - tcrit*se_p);
    ic_ls  = min(1, p_hat + tcrit*se_p);
    pct    = p_hat*100;
    li_pct = ic_li*100;
    ls_pct = ic_ls*100;
run;

/* -------------------------------------------------------------------------
   6.7 PALETA DE CORES E ORDEM DA LEGENDA
       ATTRMAP fixa a cor de cada candidato/categoria (ID "candpres" =
       Presidente | ID "candgov" = Governador). Situações de não-voto
       (Branco, Nulo, Não sei/não quero responder) recebem tons de cinza,
       para ficarem visualmente separadas dos candidatos na legenda.
       "Sem resposta" não aparece aqui pois agora é tratada como
       não-resposta (missing), não como categoria de voto (seção 2.2).
       "Outros" recebe uma cor neutra própria. Os formatos
       $presgrpord/$govgrpord fixam a ORDEM da legenda nos gráficos
       empilhados (seção 8.3): primeiro as situações de não-voto, depois
       os candidatos nomeados (ordem decrescente de votos), e "Outros"
       por último.
   ------------------------------------------------------------------------- */
data attrmap;
    length ID $10 VALUE $60 FILLCOLOR LINECOLOR MARKERCOLOR $20;

    /* situações de não-voto - tons de cinza */
    ID='candpres'; VALUE='Branco (13)';                     FILLCOLOR='cxBFBFBF'; LINECOLOR='cxBFBFBF'; MARKERCOLOR='cxBFBFBF'; output;
    ID='candpres'; VALUE='Nulo (14)';                        FILLCOLOR='cx808080'; LINECOLOR='cx808080'; MARKERCOLOR='cx808080'; output;
    ID='candpres'; VALUE='Não sei/não quero responder (15)'; FILLCOLOR='cx404040'; LINECOLOR='cx404040'; MARKERCOLOR='cx404040'; output;

    /* candidatos nomeados */
    ID='candpres'; VALUE='Luiz Inácio Lula da Silva (5)'; FILLCOLOR='red';    LINECOLOR='red';    MARKERCOLOR='red';    output;
    ID='candpres'; VALUE='Flavio Bolsonaro (3)';           FILLCOLOR='blue';   LINECOLOR='blue';   MARKERCOLOR='blue';   output;
    ID='candpres'; VALUE='Augusto Cury (0)';               FILLCOLOR='green';  LINECOLOR='green';  MARKERCOLOR='green';  output;
    ID='candpres'; VALUE='Renan Santos (7)';               FILLCOLOR='gold';   LINECOLOR='gold';   MARKERCOLOR='gold';   output;
    ID='candpres'; VALUE='Ronaldo Caiado (9)';             FILLCOLOR='purple'; LINECOLOR='purple'; MARKERCOLOR='purple'; output;
    ID='candpres'; VALUE='Samara Martins (11)';            FILLCOLOR='brown';  LINECOLOR='brown';  MARKERCOLOR='brown';  output;

    /* grupo residual (inclui Romeu Zema) */
    ID='candpres'; VALUE='Outros';                         FILLCOLOR='tan';    LINECOLOR='tan';    MARKERCOLOR='tan';    output;

    ID='candgov';  VALUE='Branco (11)';                       FILLCOLOR='cxBFBFBF'; LINECOLOR='cxBFBFBF'; MARKERCOLOR='cxBFBFBF'; output;
    ID='candgov';  VALUE='Nulo (12)';                          FILLCOLOR='cx808080'; LINECOLOR='cx808080'; MARKERCOLOR='cx808080'; output;
    ID='candgov';  VALUE='Não sei / Não quero responder (13)'; FILLCOLOR='cx404040'; LINECOLOR='cx404040'; MARKERCOLOR='cx404040'; output;

    ID='candgov';  VALUE='Leandro Grass (5)';              FILLCOLOR='red';    LINECOLOR='red';    MARKERCOLOR='red';    output;
    ID='candgov';  VALUE='Celina Leão (0)';                FILLCOLOR='gold';   LINECOLOR='gold';   MARKERCOLOR='gold';   output;
    ID='candgov';  VALUE='Paula Belmonte (6)';             FILLCOLOR='blue';   LINECOLOR='blue';   MARKERCOLOR='blue';   output;
    ID='candgov';  VALUE='Kiko Caputo (4)';                FILLCOLOR='orange'; LINECOLOR='orange'; MARKERCOLOR='orange'; output;
    ID='candgov';  VALUE='Ricardo Cappelli (9)';           FILLCOLOR='green';  LINECOLOR='green';  MARKERCOLOR='green';  output;

    ID='candgov';  VALUE='Outros';                         FILLCOLOR='tan';    LINECOLOR='tan';    MARKERCOLOR='tan';    output;
run;

proc format;
    value $presgrpord
        'Branco (13)'                     = '01'
        'Nulo (14)'                        = '02'
        'Não sei/não quero responder (15)' = '04'
        'Luiz Inácio Lula da Silva (5)'    = '05'
        'Renan Santos (7)'                 = '06'
        'Flavio Bolsonaro (3)'             = '07'
        'Ronaldo Caiado (9)'               = '08'
        'Augusto Cury (0)'                 = '09'
        'Samara Martins (11)'              = '10'
        'Outros'                           = '11';
    value $govgrpord
        'Branco (11)'                       = '01'
        'Nulo (12)'                          = '02'
        'Não sei / Não quero responder (13)' = '04'
        'Leandro Grass (5)'                  = '05'
        'Celina Leão (0)'                    = '06'
        'Ricardo Cappelli (9)'               = '07'
        'Kiko Caputo (4)'                    = '08'
        'Paula Belmonte (6)'                 = '09'
        'Outros'                             = '10';
run;

/* -------------------------------------------------------------------------
   7. ESTIMATIVAS DA INTENÇÃO DE VOTO NA POPULAÇÃO (PROC SURVEYFREQ)
      TOTAL=&N_DF. informa ao PROC SURVEYFREQ o tamanho do eleitorado do DF
      (fonte: TRE-DF, ver comentário da macro N_DF no início do script),
      ativando o cálculo do fpc. Como n válido (~391) é uma fração ínfima
      de N (~0,015%), fpc≈0,9999 - na prática equivale a tratar a
      população como infinita (mesmo resultado que se obtinha antes, sem
      TOTAL=), mas agora o fpc é calculado explicitamente a partir de uma
      fonte oficial, em vez de apenas presumido. Registros com
      presidente/governador em branco são excluídos automaticamente
      (consistente com o n_valido calculado na seção 4).
   ------------------------------------------------------------------------- */
title "Estimativa da intenção de voto p/ Presidente (IC 95%)";
proc surveyfreq data=amostra order=freq total=&N_DF.;
    tables presidente / cl;
run;

title "Estimativa da intenção de voto p/ Governador (IC 95%)";
proc surveyfreq data=amostra order=freq total=&N_DF.;
    tables governador / cl;
run;
title;

ods graphics / imagename="voto_presidente_ic";
title "Intenção de voto - Presidente (%) com IC 95%";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=var_pres_grp_pct dattrmap=attrmap;
    hbar presidente_grp / response=pct categoryorder=respdesc datalabel
         group=presidente_grp attrid=candpres noautolegend;
    scatter x=pct y=presidente_grp / xerrorlower=li_pct xerrorupper=ls_pct
            markerattrs=(symbol=none) lineattrs=(color=black thickness=2);
    xaxis label="Percentual (%)" grid;
    yaxis label="Candidato";
run;
title;

ods graphics / imagename="voto_governador_ic";
title "Intenção de voto - Governador (%) com IC 95%";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=var_gov_grp_pct dattrmap=attrmap;
    hbar governador_grp / response=pct categoryorder=respdesc datalabel
         group=governador_grp attrid=candgov noautolegend;
    scatter x=pct y=governador_grp / xerrorlower=li_pct xerrorupper=ls_pct
            markerattrs=(symbol=none) lineattrs=(color=black thickness=2);
    xaxis label="Percentual (%)" grid;
    yaxis label="Candidato";
run;
title;

/* =========================================================================
   8. ANÁLISE POR RENDA, IDADE E TURNO
      Cruza a intenção de voto (Presidente/Governador) com Faixa de renda,
      Faixa etária e Turno de coleta. O teste qui-quadrado (CHISQ) avalia
      se há associação estatisticamente significativa entre o perfil do
      respondente e o candidato escolhido. O percentual de LINHA (ROW)
      mostra como o voto se distribui DENTRO de cada subgrupo.
   ========================================================================= */

/* -------------------------------------------------------------------------
   8.1 PRESIDENTE x Faixa de Renda / Faixa Etária / Turno
   ------------------------------------------------------------------------- */
title "Presidente x Faixa de Renda";
proc freq data=amostra;
    tables renda_ord*presidente / nocol nopercent chisq;
run;
title;

title "Presidente x Faixa Etária";
proc freq data=amostra;
    tables etaria_ord*presidente / nocol nopercent chisq;
run;
title;

title "Presidente x Turno";
proc freq data=amostra;
    tables turno_ord*presidente / nocol nopercent chisq;
run;
title;

/* -------------------------------------------------------------------------
   8.2 GOVERNADOR x Faixa de Renda / Faixa Etária / Turno
   ------------------------------------------------------------------------- */
title "Governador x Faixa de Renda";
proc freq data=amostra;
    tables renda_ord*governador / nocol nopercent chisq;
run;
title;

title "Governador x Faixa Etária";
proc freq data=amostra;
    tables etaria_ord*governador / nocol nopercent chisq;
run;
title;

title "Governador x Turno";
proc freq data=amostra;
    tables turno_ord*governador / nocol nopercent chisq;
run;
title;

/* -------------------------------------------------------------------------
   8.3 GRÁFICOS: distribuição do voto (%) dentro de cada subgrupo
       (barras empilhadas a 100%, usando o percentual de linha PCT_ROW)
   ------------------------------------------------------------------------- */
proc freq data=amostra noprint;
    tables renda_ord*presidente_grp  / out=renda_pres  outpct;
    tables etaria_ord*presidente_grp / out=idade_pres   outpct;
    tables turno_ord*presidente_grp  / out=turno_pres   outpct;
    tables renda_ord*governador_grp  / out=renda_gov    outpct;
    tables etaria_ord*governador_grp / out=idade_gov    outpct;
    tables turno_ord*governador_grp  / out=turno_gov     outpct;
run;

/* ordena os datasets para a legenda/empilhamento seguirem a ordem fixada
   em $presgrpord/$govgrpord (seção 6.7): não-voto -> candidatos -> Outros */
data renda_pres; set renda_pres; grp_ord = put(presidente_grp, $presgrpord.); run;
data idade_pres; set idade_pres; grp_ord = put(presidente_grp, $presgrpord.); run;
data turno_pres; set turno_pres; grp_ord = put(presidente_grp, $presgrpord.); run;
data renda_gov;  set renda_gov;  grp_ord = put(governador_grp, $govgrpord.);  run;
data idade_gov;  set idade_gov;  grp_ord = put(governador_grp, $govgrpord.);  run;
data turno_gov;  set turno_gov;  grp_ord = put(governador_grp, $govgrpord.);  run;

proc sort data=renda_pres; by grp_ord; run;
proc sort data=idade_pres; by grp_ord; run;
proc sort data=turno_pres; by grp_ord; run;
proc sort data=renda_gov;  by grp_ord; run;
proc sort data=idade_gov;  by grp_ord; run;
proc sort data=turno_gov;  by grp_ord; run;

ods graphics / imagename="presidente_por_renda";
title "Presidente por Faixa de Renda (% dentro de cada faixa)";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=renda_pres dattrmap=attrmap;
    vbar renda_ord / response=pct_row group=presidente_grp groupdisplay=stack
         grouporder=data attrid=candpres;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa de renda" fitpolicy=rotate;
    keylegend / title="Voto" location=outside;
run;
title;

ods graphics / imagename="presidente_por_etaria";
title "Presidente por Faixa Etária (% dentro de cada faixa)";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=idade_pres dattrmap=attrmap;
    vbar etaria_ord / response=pct_row group=presidente_grp groupdisplay=stack
         grouporder=data attrid=candpres;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa etária" fitpolicy=rotate;
    keylegend / title="Voto" location=outside;
run;
title;

ods graphics / imagename="presidente_por_turno";
title "Presidente por Turno (% dentro de cada turno)";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=turno_pres dattrmap=attrmap;
    vbar turno_ord / response=pct_row group=presidente_grp groupdisplay=stack
         grouporder=data attrid=candpres;
    yaxis label="Percentual dentro do turno (%)" grid;
    xaxis label="Turno";
    keylegend / title="Voto" location=outside;
run;
title;

ods graphics / imagename="governador_por_renda";
title "Governador por Faixa de Renda (% dentro de cada faixa)";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=renda_gov dattrmap=attrmap;
    vbar renda_ord / response=pct_row group=governador_grp groupdisplay=stack
         grouporder=data attrid=candgov;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa de renda" fitpolicy=rotate;
    keylegend / title="Voto" location=outside;
run;
title;

ods graphics / imagename="governador_por_etaria";
title "Governador por Faixa Etária (% dentro de cada faixa)";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=idade_gov dattrmap=attrmap;
    vbar etaria_ord / response=pct_row group=governador_grp groupdisplay=stack
         grouporder=data attrid=candgov;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa etária" fitpolicy=rotate;
    keylegend / title="Voto" location=outside;
run;
title;

ods graphics / imagename="governador_por_turno";
title "Governador por Turno (% dentro de cada turno)";
title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
proc sgplot data=turno_gov dattrmap=attrmap;
    vbar turno_ord / response=pct_row group=governador_grp groupdisplay=stack
         grouporder=data attrid=candgov;
    yaxis label="Percentual dentro do turno (%)" grid;
    xaxis label="Turno";
    keylegend / title="Voto" location=outside;
run;
title;
