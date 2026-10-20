/* =========================================================================
   TRABALHO DE AMOSTRAGEM
   Base: Intenção de voto - Pavilhões (Brasília) - planilha v2

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
   o efeito da não-resposta sobre a precisão das estimativas - também
   por Sexo, além de Faixa de Renda, Faixa Etária e Turno.

   Todos os gráficos (perfil, não-resposta, IC e cruzamentos por
   subgrupo) são gerados diretamente neste script via `PROC SGPLOT`,
   através das macros definidas na Seção 11 - não há mais um script
   Python separado para os gráficos de IC/cruzamentos.
   ========================================================================= */

options validvarname=any;   /* permite nomes de coluna com espaço/acento no import */

%let n_nominal = 400;   /* tamanho da amostra definido para a pesquisa */
%let K         = 5;     /* intervalo da amostragem sistemática em campo */

/* Tamanho do eleitorado do Distrito Federal (população de referência para
   Presidente/Governador), conforme TRE-DF, julho/2026: "Distrito Federal
   ultrapassa 2,56 milhões de eleitores e registra 94,4% do eleitorado
   apto com biometria". Usado apenas para calcular explicitamente o fpc
   (correção de população finita) no PROC SURVEYFREQ - com n válido=264 e
   N=2.562.037, f=n/N≈0,000103 e fpc=sqrt(1-f)≈0,99995, ou seja, o efeito
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
   Baixe todos os PNGs gerados para a pasta local imagens/imagens_sas/.
   ------------------------------------------------------------------------- */
%let outpath = /home/helios_0190/imagens;

ods listing gpath="&outpath." image_dpi=200;
ods graphics on / width=800px height=500px imagefmt=png reset=all;

/* -------------------------------------------------------------------------
   1. IMPORTAÇÃO DA AMOSTRA
   ------------------------------------------------------------------------- */
proc import out=amostra_raw
    datafile="/home/u64542467/trabalho_amostragem_2026_2/intenções_de_voto_pavilhões.xlsx"
    dbms=xlsx replace;
    getnames=yes;
run;

/* -------------------------------------------------------------------------
   2. PREPARAÇÃO
      - renomeia colunas
      - remove linhas totalmente vazias (artefato da tabela do Excel)
      - cria identificador único
      - corrige espaço em branco inicial em "Samara Martins (11)" (artefato
        de digitação no Excel) e remove o sufixo numérico entre parênteses
        do nome dos candidatos (ex.: "Luiz Inácio Lula da Silva (5)" ->
        "Luiz Inácio Lula da Silva"), para os nomes ficarem exatamente como
        aparecem nas tabelas do relatório e como entrada da paleta de cores
        (Seção 10)
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

    presidente = strip(presidente);
    governador = strip(governador);
    /* remove o sufixo " (n)" do nome do candidato, se houver */
    if not missing(presidente) then
        presidente = strip(prxchange('s/\s*\(\d+\)\s*$//', 1, presidente));
    if not missing(governador) then
        governador = strip(prxchange('s/\s*\(\d+\)\s*$//', 1, governador));

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
       em vez da ordem alfabética padrão): Sexo e Turno em ordem fixa,
       Faixa de Renda e Faixa Etária em ordem crescente, com "Sem resposta"
       sempre na primeira posição. O FORMAT mantém o texto original visível
       nos eixos/tabelas, só a ordenação interna (numérica) muda.
   ------------------------------------------------------------------------- */
proc format;
    value sexofmt   1='Masculino' 2='Feminino';
    value turnofmt  1='Manhã' 2='Tarde' 3='Noite';
    value rendafmt  0='Sem resposta' 1='até R$ 1.000' 2='R$ 1.000 a R$ 2.000'
                    3='R$ 2.000 a R$ 5.000' 4='R$ 5.000 a R$ 10.000' 5='Mais de R$ 10.000';
    value etarfmt   0='Sem resposta' 1='até 18 anos' 2='19 a 24 anos' 3='25 a 29 anos'
                    4='30 a 34 anos' 5='35 a 39 anos' 6='40 a 44 anos' 7='Acima de 44 anos';
run;

data amostra;
    set amostra;

    select (sexo);
        when ('Masculino') sexo_ord = 1;
        when ('Feminino')  sexo_ord = 2;
        otherwise sexo_ord = .;
    end;

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

    format sexo_ord sexofmt. turno_ord turnofmt. renda_ord rendafmt. etaria_ord etarfmt.;
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
      Os gráficos de perfil são gerados na Seção 12, via macro grafico_perfil.
   ------------------------------------------------------------------------- */
title "Perfil da amostra (n nominal = &n_nominal.)";
proc freq data=amostra;
    tables sexo_ord etaria_ord renda_ord turno_ord / nocum;
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
      finita (fpc) aqui (o fpc só é formalizado via N_DF no PROC SURVEYFREQ
      da Seção 7). Cenário de pior caso (p=0,5) para a margem de erro,
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
   7. ESTIMATIVAS DA INTENÇÃO DE VOTO NA POPULAÇÃO (PROC SURVEYFREQ)
      TOTAL=&N_DF. informa ao PROC SURVEYFREQ o tamanho do eleitorado do DF
      (fonte: TRE-DF, ver comentário da macro N_DF no início do script),
      ativando o cálculo do fpc. Como n válido (264) é uma fração ínfima
      de N (~0,01%), fpc≈0,99995 - na prática equivale a tratar a
      população como infinita (mesmo resultado que se obtinha antes, sem
      TOTAL=), mas agora o fpc é calculado explicitamente a partir de uma
      fonte oficial, em vez de apenas presumido. Registros com
      presidente/governador em branco são excluídos automaticamente
      (consistente com o n_valido calculado na seção 4). Essas são as
      tabelas formais usadas na Seção 4.3 do relatório (o gráfico de IC
      correspondente é gerado na Seção 12, via macro grafico_ic).
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

/* =========================================================================
   8. ANÁLISE POR SEXO, FAIXA DE RENDA, FAIXA ETÁRIA E TURNO
      Cruza a intenção de voto (Presidente/Governador) com Sexo, Faixa de
      renda, Faixa etária e Turno de coleta. O teste qui-quadrado (CHISQ)
      avalia se há associação estatisticamente significativa entre o
      perfil do respondente e o candidato escolhido. Os gráficos de barras
      empilhadas correspondentes são gerados na Seção 12, via macro
      grafico_empilhado (já com o agrupamento "Outros" da Seção 9).
   ========================================================================= */

/* -------------------------------------------------------------------------
   8.0 PRESIDENTE/GOVERNADOR x SEXO
   ------------------------------------------------------------------------- */
title "Presidente x Sexo";
proc freq data=amostra;
    tables sexo*presidente / nocol nopercent chisq;
run;
title;

title "Governador x Sexo";
proc freq data=amostra;
    tables sexo*governador / nocol nopercent chisq;
run;
title;

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

/* =========================================================================
   9. GRUPO "OUTROS" (candidatos com menos de 1% dos votos válidos)
      Consolida, em cada cargo, todo candidato cuja contagem represente
      menos de 1% de n_valido - isso inclui Romeu Zema, que tem cor
      própria definida na paleta (Seção 10) mas apenas 1 voto (0,38%):
      por decisão explícita, o critério de 1% é aplicado sem exceção.
      Branco, Nulo e "Não sei/não quero responder" NUNCA entram em
      "Outros" (não são candidatos nem indecisão a descartar - são
      mantidos como categorias próprias em todos os gráficos e tabelas).
      "Sem resposta" também nunca entra, pois é tratada como não-resposta
      (missing), não como categoria de voto (Seção 2). O cálculo é
      genérico (via macro), então se recalcula sozinho a cada nova
      rodada, candidato por candidato, a partir das contagens observadas.
      Esse agrupamento vale só para os GRÁFICOS (Seção 12) - as tabelas
      (PROC SURVEYFREQ da Seção 7, PROC FREQ da Seção 8) continuam com o
      detalhamento candidato a candidato.
   ========================================================================= */
%macro agrupar_outros(var=);

    proc freq data=amostra noprint;
        tables &var. / out=_f_&var.(drop=percent where=(not missing(&var.)));
    run;

    proc sql noprint;
        select sum(count) into :nv trimmed from _f_&var.;
    quit;

    data _f_&var.;
        set _f_&var.;
        length &var._grp $60;
        if &var. in ('Branco','Nulo') or index(&var.,'Não sei')=1
            then &var._grp = &var.;
        else if count/&nv. < 0.01 then &var._grp = 'Outros';
        else &var._grp = &var.;
        keep &var. &var._grp;
    run;

    proc sql;
        create table amostra as
        select a.*, b.&var._grp
        from amostra as a
        left join _f_&var. as b
          on a.&var. = b.&var.;
    quit;

%mend agrupar_outros;

%agrupar_outros(var=presidente);
%agrupar_outros(var=governador);

/* =========================================================================
   10. PALETA DE CORES E ORDEM DA LEGENDA
       Mesma paleta validada (acessível/CVD-safe) usada nos gráficos deste
       trabalho: candidatos em ordem alfabética, depois "Outros", depois
       o bloco de situações de não-voto (Branco, Nulo, Não sei/não quero
       responder), em tons de cinza - nessa ordem na legenda dos gráficos
       empilhados (Seção 12). "Sem resposta" não aparece aqui pois nunca é
       uma categoria de voto válida (ver Seção 9).
   ========================================================================= */
data paleta_pres;
    length id $4 value $40 fillcolor $9;
    infile datalines dlm='|' dsd truncover;
    input ord value :$40. fillcolor :$9.;
    id = 'pres';
    datalines;
1|Augusto Cury|CX2CA02C
2|Flavio Bolsonaro|CX1F6FD1
3|Luiz Inácio Lula da Silva|CXE03C31
4|Renan Santos|CXD4AC0D
5|Ronaldo Caiado|CX9467BD
6|Samara Martins|CX8B4513
7|Outros|CXC2A878
8|Branco|CXBFBFBF
9|Nulo|CX808080
10|Não sei/não quero responder|CX404040
;
run;

data paleta_gov;
    length id $4 value $40 fillcolor $9;
    infile datalines dlm='|' dsd truncover;
    input ord value :$40. fillcolor :$9.;
    id = 'gov';
    datalines;
1|Celina Leão|CXD4AC0D
2|José Roberto Arruda|CX9467BD
3|Kiko Caputo|CXE8821E
4|Leandro Grass|CXE03C31
5|Paula Belmonte|CX1F6FD1
6|Ricardo Cappelli|CX1B998B
7|Outros|CXC2A878
8|Branco|CXBFBFBF
9|Nulo|CX808080
10|Não sei / Não quero responder|CX404040
;
run;

/* Attribute map usado por todos os gráficos de candidatos */
data attrmap;
    set paleta_pres paleta_gov;
    linecolor = 'white';
    drop ord;
run;

/* Cor única dos gráficos de perfil (não envolvem candidatos) */
%let cor_neutra = #C0CFE5;

/* =========================================================================
   11. MACROS DE GRÁFICO
   ========================================================================= */

/* 11.1 Perfil (barras simples com % no topo) */
%macro grafico_perfil(ord=, titulo=, xlabel=, nome=, w=900, h=550);

    proc freq data=amostra noprint;
        tables &ord. / out=_perf;
    run;

    data _perf;
        set _perf;
        lbl = cats(put(percent, 5.1), '%');
    run;

    ods graphics / reset=index imagename="&nome." width=&w.px height=&h.px;
    title1 bold "&titulo.";
    proc sgplot data=_perf noautolegend;
        vbarparm category=&ord. response=percent /
            datalabel=lbl fillattrs=(color=&cor_neutra.)
            outlineattrs=(color=white) barwidth=0.65;
        xaxis discreteorder=unformatted fitpolicy=rotate label="&xlabel.";
        yaxis label="Percentual (%)" min=0 grid;
    run;
    title;

%mend grafico_perfil;

/* 11.2 Intenção de voto com IC 95% (Cochran, divisor n-1, percentil t) */
%macro grafico_ic(grp=, attrid=, titulo=, nome=);

    proc freq data=amostra noprint;
        tables &grp. / out=_ic;
    run;

    proc sql noprint;
        select sum(count) into :nic trimmed from _ic;
    quit;

    data _ic;
        set _ic;
        n    = &nic.;
        p    = count / n;
        se   = sqrt(p * (1 - p) / (n - 1));
        tcrit = tinv(0.975, n - 1);
        me   = tcrit * se;
        pct  = 100 * p;
        li   = max(0,   100 * (p - me));
        ls   = min(100, 100 * (p + me));
        lbl  = cats(put(pct, 5.1), '%');
        rename &grp. = categoria;
    run;

    proc sort data=_ic; by pct; by descending pct; run;   /* maior no topo do gráfico */

    ods graphics / reset=index imagename="&nome." width=900px height=600px;
    title1 bold "&titulo.";
    title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
    proc sgplot data=_ic dattrmap=attrmap noautolegend;
        hbarparm category=categoria response=pct /
            limitlower=li limitupper=ls group=categoria attrid=&attrid.
            datalabel=lbl groupdisplay=cluster barwidth=0.65;
        yaxis discreteorder=data display=(nolabel);
        xaxis label="Percentual (%)" min=0 grid;
    run;
    title;

%mend grafico_ic;

/* 11.3 Barras empilhadas: % de cada voto dentro de cada categoria */
%macro grafico_empilhado(ord=, grp=, pal=, attrid=, titulo=, xlabel=, nome=);

    proc freq data=amostra(where=(not missing(&grp.) and not missing(&ord.))) noprint;
        tables &ord. * &grp. / out=_emp outpct;
    run;

    proc sql;
        create table _emp2 as
        select a.*, b.ord as grp_ord
        from _emp as a
        left join &pal. as b
          on a.&grp. = b.value
        order by a.&ord., b.ord;
    quit;

    ods graphics / reset=index imagename="&nome." width=950px height=600px;
    title1 bold "&titulo.";
    title2 "Candidatos com menos de 1% dos votos agrupados em 'Outros'";
    proc sgplot data=_emp2 dattrmap=attrmap;
        vbarparm category=&ord. response=pct_row /
            group=&grp. attrid=&attrid. groupdisplay=stack
            grouporder=data barwidth=0.65;
        xaxis discreteorder=unformatted fitpolicy=rotate label="&xlabel.";
        yaxis label="Percentual dentro de cada categoria (%)" min=0 max=100 grid;
        keylegend / title="Voto" position=right across=1;
    run;
    title;

%mend grafico_empilhado;

/* =========================================================================
   12. EXECUÇÃO
   ========================================================================= */

/* Perfil */
%grafico_perfil(ord=sexo_ord,   titulo=Distribuição por Sexo,                    xlabel=Sexo,           nome=perfil_sexo,  w=700);
%grafico_perfil(ord=etaria_ord, titulo=Distribuição por Faixa Etária,            xlabel=Faixa etária,   nome=perfil_etaria);
%grafico_perfil(ord=renda_ord,  titulo=Distribuição por Faixa de Renda Familiar, xlabel=Faixa de renda, nome=perfil_renda);
%grafico_perfil(ord=turno_ord,  titulo=Distribuição por Turno de Coleta,         xlabel=Turno,          nome=perfil_turno, w=700);

/* Intenção de voto com IC 95% */
%grafico_ic(grp=presidente_grp, attrid=pres,
            titulo=Intenção de voto - Presidente (%) com IC 95%, nome=voto_presidente_ic);
%grafico_ic(grp=governador_grp, attrid=gov,
            titulo=Intenção de voto - Governador (%) com IC 95%, nome=voto_governador_ic);

/* Cruzamentos por subgrupo - Presidente */
%grafico_empilhado(ord=sexo_ord,   grp=presidente_grp, pal=paleta_pres, attrid=pres,
    titulo=Presidente por Sexo (% dentro de cada sexo),
    xlabel=Sexo, nome=presidente_por_sexo);
%grafico_empilhado(ord=renda_ord,  grp=presidente_grp, pal=paleta_pres, attrid=pres,
    titulo=Presidente por Faixa de Renda (% dentro de cada faixa),
    xlabel=Faixa de renda, nome=presidente_por_renda);
%grafico_empilhado(ord=etaria_ord, grp=presidente_grp, pal=paleta_pres, attrid=pres,
    titulo=Presidente por Faixa Etária (% dentro de cada faixa),
    xlabel=Faixa etária, nome=presidente_por_etaria);
%grafico_empilhado(ord=turno_ord,  grp=presidente_grp, pal=paleta_pres, attrid=pres,
    titulo=Presidente por Turno (% dentro de cada turno),
    xlabel=Turno, nome=presidente_por_turno);

/* Cruzamentos por subgrupo - Governador */
%grafico_empilhado(ord=sexo_ord,   grp=governador_grp, pal=paleta_gov, attrid=gov,
    titulo=Governador por Sexo (% dentro de cada sexo),
    xlabel=Sexo, nome=governador_por_sexo);
%grafico_empilhado(ord=renda_ord,  grp=governador_grp, pal=paleta_gov, attrid=gov,
    titulo=Governador por Faixa de Renda (% dentro de cada faixa),
    xlabel=Faixa de renda, nome=governador_por_renda);
%grafico_empilhado(ord=etaria_ord, grp=governador_grp, pal=paleta_gov, attrid=gov,
    titulo=Governador por Faixa Etária (% dentro de cada faixa),
    xlabel=Faixa etária, nome=governador_por_etaria);
%grafico_empilhado(ord=turno_ord,  grp=governador_grp, pal=paleta_gov, attrid=gov,
    titulo=Governador por Turno (% dentro de cada turno),
    xlabel=Turno, nome=governador_por_turno);

ods graphics off;
