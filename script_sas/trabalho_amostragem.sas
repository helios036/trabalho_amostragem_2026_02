/* =========================================================================
   TRABALHO DE AMOSTRAGEM
   Fonte: Intenção de voto - Pavilhões (Brasília) - planilha v2
   ========================================================================= */

options validvarname=any;

%let n_nominal = 400;
%let K         = 5;

/* Fonte: TRE-DF, julho/2026 - https://www.tre-df.jus.br/comunicacao/noticias/2026/Julho/distrito-federal-ultrapassa-2-56-milhoes-de-eleitores-e-registra-94-4-do-eleitorado-apto-com-biometria-1 */
%let N_DF = 2562037;

%let outpath = /home/u64538097/Trabalho_amostragem/imagens; 
 
ods listing gpath="&outpath." image_dpi=200;
ods graphics on / width=800px height=500px imagefmt=png reset=all;

proc import out=amostra_raw
    datafile="/home/u64538097/Trabalho_amostragem/intenções_de_voto_pavilhões_v2.xlsx"
    dbms=xlsx replace;
    getnames=yes;
run;

/* -------------------------------------------------------------------------
TRATAMENTO DOS DADOS
   ------------------------------------------------------------------------- */
data amostra;
    set amostra_raw;
    rename
        'Sexo'n                     = sexo
        'Faixa etária'n             = faixa_etaria
        'Faixa de renda familiar'n   = faixa_renda
        'Presidente'n                = presidente
        'Governador'n                = governador
        'Turno'n                     = turno;
run;

data amostra;
    set amostra;
    if missing(Timestamp) then delete;
    id = _n_;

    presidente = strip(presidente);
    governador = strip(governador);
    faixa_etaria = strip(faixa_etaria);
    faixa_renda = strip(faixa_renda);

    /* remove o sufixo " (n)" do nome do candidato, se houver */
    if not missing(presidente) then
        presidente = strip(prxchange('s/\s*\(\d+\)\s*$//', 1, presidente));

    if not missing(governador) then
        governador = strip(prxchange('s/\s*\(\d+\)\s*$//', 1, governador));
        
    /* Padroniza as respostas de Presidente e Governador */
	if upcase(compbl(strip(presidente))) = 'NÃO SEI/NÃO QUERO RESPONDER' then
    presidente = 'Não sei/não quero responder';

	if upcase(compbl(strip(governador))) = 'NÃO SEI / NÃO QUERO RESPONDER' then
    governador = 'Não sei/não quero responder';    

    length status_respondente $20 regra_aplicada $20;

    status_respondente = 'Respondente';
    regra_aplicada = 'Nenhuma';

    /* Regra 1 */
    if faixa_etaria = 'Sem resposta'
       and faixa_renda = 'Sem resposta'
       and presidente = 'Não sei/não quero responder'
       and governador = 'Não sei/não quero responder' then
        regra_aplicada = 'Regra 1';

    /* Regra 2 */
    else if missing(faixa_etaria)
        and missing(faixa_renda)
        and missing(presidente)
        and missing(governador) then
        regra_aplicada = 'Regra 2';

    /* Regra 3 */
    else if missing(faixa_etaria)
        and faixa_renda = 'Sem resposta'
        and presidente = 'Não sei/não quero responder'
        and governador = 'Não sei/não quero responder' then
        regra_aplicada = 'Regra 3';

    /* Regra 4 */
    else if faixa_etaria = 'Sem resposta'
        and missing(faixa_renda)
        and presidente = 'Não sei/não quero responder'
        and governador = 'Não sei/não quero responder' then
        regra_aplicada = 'Regra 4';

    /* Regra 5 */
    else if faixa_etaria = 'Sem resposta'
        and faixa_renda = 'Sem resposta'
        and missing(presidente)
        and missing(governador) then
        regra_aplicada = 'Regra 5';

    /* Regra 6 */
    else if faixa_etaria = 'Sem resposta'
        and missing(faixa_renda)
        and missing(presidente)
        and missing(governador) then
        regra_aplicada = 'Regra 6';

    /* Regra 7 */
    else if faixa_renda = 'Sem resposta'
        and missing(faixa_etaria)
        and missing(presidente)
        and missing(governador) then
        regra_aplicada = 'Regra 7';

    /* Classificação e limpeza dos não respondentes */
    if regra_aplicada ne 'Nenhuma' then do;
        status_respondente = 'Não-respondente';
        faixa_etaria = '';
        faixa_renda = '';
        presidente = '';
        governador = '';
    end;
run;

/* -------------------------------------------------------------------------
Criação dos Gráficos
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
   MÉTODO: JUSTIFICATIVA DO TAMANHO DA AMOSTRA
            n0 = 2² * 0,5*(1-0,5) / e² = 1 / e²
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
    PERFIL DA AMOSTRA (estatísticas descritivas)
   ------------------------------------------------------------------------- */
title "Perfil da amostra (n nominal = &n_nominal.)";
proc freq data=amostra;
    tables sexo_ord etaria_ord renda_ord turno_ord / nocum;
run;
title;
  
/* ------------------------------------------------------------------------- 
	6.1 IDENTIFICAÇÃO E CONTAGEM DOS NÃO-RESPONDENTES TOTAIS
  - calcula o percentual de não-respondentes totais
------------------------------------------------------------------------- */

title "Respondentes e não-respondentes totais";
proc freq data=amostra;
    tables status_respondente / missing nocum;
run;

title;

/* -------------------------------------------------------------------------
   6.2 NÃO-RESPOSTA
     Analise sobre os não respondentes.
   ------------------------------------------------------------------------- */
  
title "Respondentes e não respondentes totais";
proc freq data=amostra;
    tables status_respondente / missing nocum;
run;

title "Não-resposta total por Sexo";
proc freq data=amostra;
    tables sexo*status_respondente / nocol nopercent;
run;
title;

ods graphics / imagename="naoresposta_total";
title "Respondentes e não respondentes totais";
proc sgplot data=amostra;
    vbar status_respondente / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label=" ";
run;
title;

ods graphics / imagename="naoresposta_sexo";
title "Não-resposta total por Sexo";
proc sgplot data=amostra;
    vbar sexo / group=status_respondente
                groupdisplay=cluster
                stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Sexo";
run;
title;

data _null_;
    set amostra end=eof;
    retain n_nao_resp 0 n_total 0;

    n_total + 1;

    if status_respondente = 'Não-respondente' then
        n_nao_resp + 1;

    if eof then do;
        n_resp = n_total - n_nao_resp;
        
        pct_nao_resp = (n_nao_resp / n_total) * 100;
        pct_resp     = (n_resp / n_total) * 100;

        call symputx('n_nao_resp', n_nao_resp);
        call symputx('n_resp', n_resp);
        call symputx('n_total_real', n_total);

        put "n total da amostra: " n_total;
        put "Não respondentes totais: " n_nao_resp
            " (" pct_nao_resp 6.2 "%)";
        put "Respondentes totais: " n_resp
            " (" pct_resp 6.2 "%)";
    end;
run;

/* -------------------------------------------------------------------------
   6.3 NÃO RESPOSTA ÀS PERGUNTAS DE PRESIDENTE E GOVERNADOR
   ------------------------------------------------------------------------- */

data amostra_respondentes;
    set amostra;

    where status_respondente = 'Respondente';

    length resp_presidente resp_governador $20;

    if missing(presidente)
       or upcase(compbl(strip(presidente))) = 'SEM RESPOSTA'
    then resp_presidente = 'Recusou/omitiu';
    else resp_presidente = 'Respondeu';

    if missing(governador)
       or upcase(compbl(strip(governador))) = 'SEM RESPOSTA'
    then resp_governador = 'Recusou/omitiu';
    else resp_governador = 'Respondeu';

run;

title "Não resposta às perguntas eleitorais entre os respondentes";

proc freq data=amostra_respondentes;
    tables resp_presidente resp_governador / nocum;
run;

title;

/* Contagem das respostas válidas para cada pergunta */
proc sql noprint;
    select count(*)
    into :n_valid_pres trimmed
    from amostra_respondentes
    where not missing(presidente)
      and upcase(compbl(strip(presidente))) ne 'SEM RESPOSTA';

    select count(*)
    into :n_valid_gov trimmed
    from amostra_respondentes
    where not missing(governador)
      and upcase(compbl(strip(governador))) ne 'SEM RESPOSTA';
quit;

/* Registra os tamanhos válidos no LOG do SAS */
%put NOTE: Respostas válidas para Presidente = &n_valid_pres.;
%put NOTE: Respostas válidas para Governador = &n_valid_gov.;

/* -------------------------------------------------------------------------
   MARGEM DE ERRO: NOMINAL (n=400) x EFETIVA (descontando não-resposta)
   
   FÓRMULA UTILIZADA: e = t(0,975; n-1) * sqrt[p*(1-p)/n] 
   ------------------------------------------------------------------------- */
	/* Cálculo das margens de erro nominal e efetivas */

data comparacao_me;
    length estimativa $25;
    p = 0.5;

    t_nominal = tinv(0.975, &n_nominal. - 1);
    e_nominal = t_nominal * sqrt(p*(1-p) / &n_nominal.);

    estimativa = 'Nominal';
    n = &n_nominal.;
    margem = e_nominal;
    output;

    t_pres = tinv(0.975, &n_valid_pres. - 1);
    e_pres = t_pres * sqrt(p*(1-p) / &n_valid_pres.);

    estimativa = 'Presidente';
    n = &n_valid_pres.;
    margem = e_pres;
    output;

    t_gov = tinv(0.975, &n_valid_gov. - 1);
    e_gov = t_gov * sqrt(p*(1-p) / &n_valid_gov.);

    estimativa = 'Governador';
    n = &n_valid_gov.;
    margem = e_gov;
    output;

    keep estimativa n margem;
run;


	/* Comparação entre as margens de erro */

proc sql noprint;
    select margem into :me_nominal trimmed
    from comparacao_me
    where estimativa = 'Nominal';
quit;

data comparacao_me;
    set comparacao_me;

    if estimativa = 'Nominal' then do;
        diferenca_pp = 0;
        aumento_pct = 0;
    end;
    else do;
        diferenca_pp = (margem - &me_nominal.) * 100;
        aumento_pct = (margem / &me_nominal. - 1) * 100;
    end;

    margem_pct = margem * 100;

    label
        estimativa   = 'Estimativa'
        n            = 'N válido'
        margem_pct   = 'Margem de erro (%)'
        diferenca_pp = 'Diferença (p.p.)'
        aumento_pct  = 'Aumento relativo (%)';

    format margem_pct diferenca_pp aumento_pct 8.2;
run;

title "Comparação da margem de erro nominal e efetiva";

proc print data=comparacao_me noobs label;
    var estimativa n margem_pct diferenca_pp aumento_pct;
run;

title;

/* =========================================================================
   8. ESTIMAÇÃO DAS PROPORÇÕES DE INTENÇÃO DE VOTO E INTERVALO DE CONFIANÇA
       Var(p_hat) = p_hat*(1-p_hat)/(n-1)
   ========================================================================= */


	/* Frequências absolutas por candidato */

proc freq data=amostra noprint;
    tables presidente / out=freq_pres;
    tables governador / out=freq_gov;
run;


	/* Consolidação das frequências e cálculo das estimativas */

data me_candidatos;
    length cargo $12 candidato $60;

    set freq_pres(in=a)
        freq_gov(in=b);

    /* Identifica o cargo e o número de respostas válidas */

    if a then do;
        if missing(presidente)
           or upcase(compbl(strip(presidente))) = 'SEM RESPOSTA'
        then delete;

        cargo = 'Presidente';
        candidato = presidente;
        n = &n_valid_pres.;
    end;

    else if b then do;
        if missing(governador)
           or upcase(compbl(strip(governador))) = 'SEM RESPOSTA'
        then delete;

        cargo = 'Governador';
        candidato = governador;
        n = &n_valid_gov.;
    end;

    /* Proporção estimada */

    p_hat = count / n;
    proporcao = p_hat * 100;

    /* Variância e erro-padrão da proporção */

    var_p = p_hat * (1-p_hat) / (n-1);
    se_p = sqrt(var_p);

    /* Margem de erro e intervalo de confiança de 95% */

    tcrit = tinv(0.975, n-1);

    margem_pp = tcrit * se_p * 100;

    ic_inf = max(0, (p_hat - tcrit*se_p) * 100);
    ic_sup = min(100, (p_hat + tcrit*se_p) * 100);

    label
        cargo      = 'Cargo'
        candidato  = 'Candidato'
        count      = 'Frequência'
        n          = 'N válido'
        proporcao  = 'Proporção (%)'
        var_p      = 'Variância da proporção'
        se_p       = 'Erro-padrão'
        margem_pp  = 'Margem de erro (p.p.)'
        ic_inf     = 'IC 95% - limite inferior'
        ic_sup     = 'IC 95% - limite superior';

    format
        proporcao margem_pp ic_inf ic_sup 7.2
        var_p 12.8
        se_p 10.6;

    keep cargo candidato count n proporcao var_p se_p
         margem_pp ic_inf ic_sup;
run;

proc sort data=me_candidatos;
    by cargo descending proporcao;
run;

	/* Tabela final de variância, erro-padrão e IC de 95% */

title "Variância, erro-padrão e IC 95% por candidato";

proc print data=me_candidatos noobs label;
    var cargo candidato count n proporcao
        var_p se_p margem_pp ic_inf ic_sup;
run;

title;
/* -------------------------------------------------------------------------
   9. ESTIMATIVAS DA INTENÇÃO DE VOTO NA POPULAÇÃO (PROC SURVEYFREQ)
       
   ------------------------------------------------------------------------- */ 
title "Estimativa da intenção de voto p/ Presidente (IC 95%)";
proc surveyfreq data=amostra order=freq total=&N_DF.;
    tables presidente / var cl;
run;

title "Estimativa da intenção de voto p/ Governador (IC 95%)";
proc surveyfreq data=amostra order=freq total=&N_DF.;
    tables governador / var cl;
run;
title;

/* =========================================================================
   10. ANÁLISE POR SEXO, FAIXA DE RENDA, FAIXA ETÁRIA E TURNO
   ========================================================================= */

/* -------------------------------------------------------------------------
   10.0 PRESIDENTE/GOVERNADOR x SEXO
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
   10.1 PRESIDENTE x Faixa de Renda / Faixa Etária / Turno
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
   10.2 GOVERNADOR x Faixa de Renda / Faixa Etária / Turno
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
   11. GRUPO "OUTROS" (candidatos com menos de 1% dos votos válidos)
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
   12. PALETA DE CORES E ORDEM DA LEGENDA
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
10|Não sei/não quero responder|CX404040
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
   13. MACROS DE GRÁFICO
   ========================================================================= */

/* 13.1 Perfil (barras simples com % no topo) */
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

/* 13.2 Intenção de voto com IC 95% (Cochran, divisor n-1, percentil t) */
%macro grafico_ic(grp=, attrid=, titulo=, nome=, base=respondentes);

    %if &base.=total %then %do;
        proc freq data=amostra noprint;
            tables &grp. / missing out=_ic;
        run;
    %end;
    %else %do;
        proc freq data=amostra(where=(not missing(&grp.))) noprint;
            tables &grp. / out=_ic;
        run;
    %end;

    proc sql noprint;
        select sum(count) into :nic trimmed from _ic;
    quit;

    data _ic;
        set _ic;
        n = &nic.;
        p = count / n;
        se = sqrt(p * (1-p) / (n-1));
        tcrit = tinv(0.975, n-1);
        me = tcrit * se;
        pct = 100 * p;
        li = max(0, 100 * (p-me));
        ls = min(100, 100 * (p+me));
        lbl = cats(put(pct, 5.1), '%');
        rename &grp. = categoria;
    run;

    proc sort data=_ic;
        by descending pct;
    run;

    ods graphics / reset=index imagename="&nome." width=900px height=600px;
    title1 bold "&titulo.";
    proc sgplot data=_ic dattrmap=attrmap noautolegend;
        hbarparm category=categoria response=pct /
            limitlower=li limitupper=ls group=categoria
            attrid=&attrid. datalabel=lbl
            groupdisplay=cluster barwidth=0.65;
        yaxis discreteorder=data display=(nolabel);
        xaxis label="Percentual (%)" min=0 grid;
    run;
    title;

%mend grafico_ic;

/* 13.3 Intenção de voto com IC 95% - somente votos válidos
   Exclui Branco, Nulo e Não sei/não quero responder.
   O denominador passa a ser a soma dos votos dos candidatos. */

%macro grafico_ic_validos(grp=, attrid=, titulo=, nome=);

    /* Frequências apenas dos votos válidos */
    proc freq data=amostra(where=(
        not missing(&grp.)
        and &grp. not in (
            'Branco',
            'Nulo',
            'Não sei/não quero responder'
        )
    )) noprint;
        tables &grp. / out=_ic_validos;
    run;

    /* Total de votos válidos */
    proc sql noprint;
        select sum(count)
        into :n_validos trimmed
        from _ic_validos;
    quit;

    /* Proporções, erro-padrão e IC de 95% */
    data _ic_validos;
        set _ic_validos;

        n = &n_validos.;
        p = count / n;

        se = sqrt(p * (1-p) / (n-1));
        tcrit = tinv(0.975, n-1);
        me = tcrit * se;

        pct = 100 * p;
        li = max(0, 100 * (p - me));
        ls = min(100, 100 * (p + me));

        lbl = cats(put(pct, 5.1), '%');

        rename &grp. = categoria;
    run;

    proc sort data=_ic_validos;
        by descending pct;
    run;

    ods graphics / reset=index
        imagename="&nome."
        width=900px height=600px;

    title1 bold "&titulo.";
    title2 "Somente votos válidos (sem Branco, Nulo e Não sei/não quero responder)";

    proc sgplot data=_ic_validos dattrmap=attrmap noautolegend;;
        hbarparm category=categoria response=pct /
            limitlower=li
            limitupper=ls
            group=categoria
            attrid=&attrid.
            datalabel=lbl
            groupdisplay=cluster 
            barwidth=0.65;

        yaxis discreteorder=data
              display=(noticks)
              label="Candidato";
        xaxis label="Percentual dos votos válidos (%)"
              min=0
              grid;
    run;

    title;

    /* Registra o denominador utilizado */
    %put NOTE: Total de votos válidos para &grp. = &n_validos.;

%mend grafico_ic_validos;

/* 13.4 Barras empilhadas: % de cada voto dentro de cada categoria */
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
   14. EXECUÇÃO
   ========================================================================= */

/* Perfil */
%grafico_perfil(ord=sexo_ord,   titulo=Distribuição por Sexo,                    xlabel=Sexo,           nome=perfil_sexo,  w=700);
%grafico_perfil(ord=etaria_ord, titulo=Distribuição por Faixa Etária,            xlabel=Faixa etária,   nome=perfil_etaria);
%grafico_perfil(ord=renda_ord,  titulo=Distribuição por Faixa de Renda Familiar, xlabel=Faixa de renda, nome=perfil_renda);
%grafico_perfil(ord=turno_ord,  titulo=Distribuição por Turno de Coleta,         xlabel=Turno,          nome=perfil_turno, w=700);

/* Intenção de voto com IC 95% */
/* Intenção de voto com IC 95% - somente votos válidos */
%grafico_ic_validos(grp=presidente_grp, attrid=pres,
                    titulo=Intenção de voto - Presidente (votos válidos) com IC 95%, nome=voto_presidente_ic_validos);
/* Intenção de voto em Presidente: respondentes (261) */
%grafico_ic(grp=presidente_grp, attrid=pres,
            titulo=Intenção de voto - Presidente (%) com IC 95% (Respondentes), nome=voto_presidente_ic_respondentes, base=respondentes);
/* Intenção de voto em Presidente: amostra total */
%grafico_ic(grp=presidente_grp, attrid=pres,
            titulo=Intenção de voto - Presidente (%) com IC 95% (Amostra Total), nome=voto_presidente_ic_total, base=total);
            
/* Intenção de voto com IC 95% - somente votos válidos */
%grafico_ic_validos(grp=governador_grp, attrid=gov,
                    titulo=Intenção de voto - Governador (votos válidos) com IC 95%, nome=voto_governador_ic_validos);           
/* Intenção de voto em Governador: respondentes (261) */
%grafico_ic(grp=governador_grp, attrid=gov,
            titulo=Intenção de voto - Governador (%) com IC 95% (Respondentes), nome=voto_governador_ic_respondentes, base=respondentes);
/* Intenção de voto em Governador: amostra total */
%grafico_ic(grp=governador_grp, attrid=gov,
            titulo=Intenção de voto - Governador (%) com IC 95% (Amostra Total), nome=voto_governador_ic_total, base=total);

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
