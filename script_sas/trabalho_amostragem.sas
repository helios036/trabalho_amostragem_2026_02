/* =========================================================================
   TRABALHO DE AMOSTRAGEM
   Base: Intenção de voto - Pavilhões (Brasília)

   PLANO AMOSTRAL DE CAMPO: Amostragem Sistemática, com intervalo K=2
   (a cada 2 pessoas que passavam pelo pavilhão, 1 era abordada, com
   início aleatório sorteado entre a 1ª e a 2ª pessoa da sequência).
   Amostra nominal: n = 400, de uma população desconhecida/grande
   (sem correção de população finita - fpc).

   Para fins de cálculo de variância/erro-padrão das estimativas, a
   amostragem sistemática é tratada de forma equivalente à AAS - essa é
   a prática padrão quando não há suspeita de periodicidade/tendência
   na ordem de chegada das pessoas no pavilhão (não há motivo para
   acreditar que a cada 2ª pessoa exista um padrão sistemático de
   intenção de voto). Essa suposição deve ser declarada no relatório.

   Objetivo: estimar as proporções de intenção de voto na população,
   com variância, margem de erro, intervalo de confiança, e avaliar
   o efeito da não-resposta sobre a precisão das estimativas.
   ========================================================================= */

options validvarname=any;   /* permite nomes de coluna com espaço/acento no import */

%let n_nominal = 400;   /* tamanho da amostra definido para a pesquisa */
%let K         = 2;     /* intervalo da amostragem sistemática em campo */

/* -------------------------------------------------------------------------
   SALVAR GRÁFICOS COMO .PNG
   Ajuste "outpath" para o caminho da pasta "imagens" dentro do seu Files
   (Home) no SAS Studio — mesmo tipo de ajuste já feito no datafile= da
   PROC IMPORT (o SAS Studio roda num servidor Linux, não no seu PC).
   ------------------------------------------------------------------------- */
%let outpath = /home/SEU_USUARIO/imagens;   /* <-- AJUSTE AQUI */

ods listing gpath="&outpath." image_dpi=200;
ods graphics on / width=800px height=500px imagefmt=png reset=all;

/* -------------------------------------------------------------------------
   1. IMPORTAÇÃO DA AMOSTRA
   ------------------------------------------------------------------------- */
proc import out=amostra_raw
    datafile="C:\modelos_ia_gen\trabalho_amostragem\intenções_de_voto_pavilhões.xlsx"
    dbms=xlsx replace;
    getnames=yes;
run;

/* -------------------------------------------------------------------------
   2. PREPARAÇÃO
      - renomeia colunas
      - remove linhas totalmente vazias (artefato da tabela do Excel:
        o arquivo possui 18 linhas em branco no final, sem nenhum dado -
        não são respondentes, por isso são descartadas)
      - cria identificador único
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
      Quantifica quantos respondentes deixaram Presidente/Governador em
      branco (diferente da categoria "Não sei/Não quero responder", que é
      uma resposta válida registrada). Também verifica se a não-resposta
      se distribui igualmente entre os sexos (checagem de não-resposta
      diferencial, que pode indicar viés).
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
      finita (fpc). Cenário de pior caso (p=0,5) para a margem de erro:

           e = Z * sqrt( p*(1-p) / n )

      A não-resposta reduz o n efetivo de cada pergunta, o que AUMENTA
      a margem de erro em relação ao n nominal da amostra coletada.
   ------------------------------------------------------------------------- */
data _null_;
    Z = 1.96;      /* 95% de confiança */
    p = 0.5;       /* cenário de variância máxima */

    e_nominal = Z * sqrt( p*(1-p) / &n_nominal. );
    e_pres    = Z * sqrt( p*(1-p) / &n_valid_pres. );
    e_gov     = Z * sqrt( p*(1-p) / &n_valid_gov. );

    put "Margem de erro c/ n nominal (&n_nominal.): " e_nominal best6.;
    put "Margem de erro efetiva - Presidente (n=&n_valid_pres.): " e_pres best6.;
    put "Margem de erro efetiva - Governador (n=&n_valid_gov.): " e_gov best6.;
run;

/* -------------------------------------------------------------------------
   6. VARIÂNCIA DAS ESTIMATIVAS (cálculo explícito pela fórmula)
      Para cada candidato: p_hat = count/n ; Var(p_hat) = p_hat*(1-p_hat)/n
      (população infinita, sem fpc). Serve para conferir "na mão" os
      desvios-padrão/IC que o PROC SURVEYFREQ calcula na seção 7.
   ------------------------------------------------------------------------- */
proc freq data=amostra noprint;
    tables presidente / out=freq_pres (where=(not missing(presidente)));
    tables governador / out=freq_gov  (where=(not missing(governador)));
run;

data var_pres;
    set freq_pres;
    n      = &n_valid_pres.;
    p_hat  = count / n;
    var_p  = p_hat*(1-p_hat) / n;
    se_p   = sqrt(var_p);
    ic_li  = max(0, p_hat - 1.96*se_p);
    ic_ls  = min(1, p_hat + 1.96*se_p);
run;

data var_gov;
    set freq_gov;
    n      = &n_valid_gov.;
    p_hat  = count / n;
    var_p  = p_hat*(1-p_hat) / n;
    se_p   = sqrt(var_p);
    ic_li  = max(0, p_hat - 1.96*se_p);
    ic_ls  = min(1, p_hat + 1.96*se_p);
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

/* Converte para percentual (mais legível no gráfico) */
data var_pres_pct;
    set var_pres;
    pct    = p_hat*100;
    li_pct = ic_li*100;
    ls_pct = ic_ls*100;
run;

data var_gov_pct;
    set var_gov;
    pct    = p_hat*100;
    li_pct = ic_li*100;
    ls_pct = ic_ls*100;
run;

/* -------------------------------------------------------------------------
   7. ESTIMATIVAS DA INTENÇÃO DE VOTO NA POPULAÇÃO (PROC SURVEYFREQ)
      PROC SURVEYFREQ sem TOTAL=/RATE= assume AAS de uma população
      grande/infinita (sem fpc) - adequado ao cenário. Registros com
      presidente/governador em branco são excluídos automaticamente
      (consistente com o n_valido calculado na seção 4).
   ------------------------------------------------------------------------- */
title "Estimativa da intenção de voto p/ Presidente (IC 95%)";
proc surveyfreq data=amostra order=freq;
    tables presidente / cl;
run;

title "Estimativa da intenção de voto p/ Governador (IC 95%)";
proc surveyfreq data=amostra order=freq;
    tables governador / cl;
run;
title;

ods graphics / imagename="voto_presidente_ic";
title "Intenção de voto - Presidente (%) com IC 95%";
proc sgplot data=var_pres_pct;
    hbar presidente / response=pct categoryorder=respdesc datalabel;
    scatter x=pct y=presidente / xerrorlower=li_pct xerrorupper=ls_pct
            markerattrs=(symbol=none) lineattrs=(color=black thickness=2);
    xaxis label="Percentual (%)" grid;
    yaxis label="Candidato";
run;
title;

ods graphics / imagename="voto_governador_ic";
title "Intenção de voto - Governador (%) com IC 95%";
proc sgplot data=var_gov_pct;
    hbar governador / response=pct categoryorder=respdesc datalabel;
    scatter x=pct y=governador / xerrorlower=li_pct xerrorupper=ls_pct
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
    tables renda_ord*presidente  / out=renda_pres  outpct;
    tables etaria_ord*presidente / out=idade_pres   outpct;
    tables turno_ord*presidente  / out=turno_pres   outpct;
    tables renda_ord*governador  / out=renda_gov    outpct;
    tables etaria_ord*governador / out=idade_gov    outpct;
    tables turno_ord*governador  / out=turno_gov     outpct;
run;

ods graphics / imagename="presidente_por_renda";
title "Presidente por Faixa de Renda (% dentro de cada faixa)";
proc sgplot data=renda_pres;
    vbar renda_ord / response=pct_row group=presidente groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa de renda" fitpolicy=rotate;
    keylegend / title="Candidato" location=outside;
run;
title;

ods graphics / imagename="presidente_por_etaria";
title "Presidente por Faixa Etária (% dentro de cada faixa)";
proc sgplot data=idade_pres;
    vbar etaria_ord / response=pct_row group=presidente groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa etária" fitpolicy=rotate;
    keylegend / title="Candidato" location=outside;
run;
title;

ods graphics / imagename="presidente_por_turno";
title "Presidente por Turno (% dentro de cada turno)";
proc sgplot data=turno_pres;
    vbar turno_ord / response=pct_row group=presidente groupdisplay=stack;
    yaxis label="Percentual dentro do turno (%)" grid;
    xaxis label="Turno";
    keylegend / title="Candidato" location=outside;
run;
title;

ods graphics / imagename="governador_por_renda";
title "Governador por Faixa de Renda (% dentro de cada faixa)";
proc sgplot data=renda_gov;
    vbar renda_ord / response=pct_row group=governador groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa de renda" fitpolicy=rotate;
    keylegend / title="Candidato" location=outside;
run;
title;

ods graphics / imagename="governador_por_etaria";
title "Governador por Faixa Etária (% dentro de cada faixa)";
proc sgplot data=idade_gov;
    vbar etaria_ord / response=pct_row group=governador groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid;
    xaxis label="Faixa etária" fitpolicy=rotate;
    keylegend / title="Candidato" location=outside;
run;
title;

ods graphics / imagename="governador_por_turno";
title "Governador por Turno (% dentro de cada turno)";
proc sgplot data=turno_gov;
    vbar turno_ord / response=pct_row group=governador groupdisplay=stack;
    yaxis label="Percentual dentro do turno (%)" grid;
    xaxis label="Turno";
    keylegend / title="Candidato" location=outside;
run;
title;
