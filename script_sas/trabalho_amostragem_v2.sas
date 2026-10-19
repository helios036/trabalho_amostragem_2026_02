/* =========================================================================
   VERSÃO 2 — ANÁLISE EXPLORATÓRIA DAS INTENÇÕES DE VOTO
   Base: Intenções de voto - Pavilhões (Brasília)

   OBJETIVO
   --------
   Esta versão prioriza as análises substantivas da pesquisa:
     1) Perfil da amostra;
     2) Intenção de voto geral para Presidente e Governador;
     3) Top 2 candidatos + Branco + Nulo nos principais gráficos;
     4) Intenção de voto por Sexo;
     5) Intenção de voto por Faixa Etária;
     6) Intenção de voto por Faixa de Renda;
     7) Intenção de voto por Turno;
     8) Testes qui-quadrado de associação;
     9) Análise de não-resposta;
    10) Intervalos de confiança para as intenções gerais.

   IMPORTANTE
   ----------
   - Os candidatos Top 2 são identificados AUTOMATICAMENTE a partir dos dados.
   - Branco e Nulo permanecem separados.
   - Os demais candidatos e "Não sei / Não quero responder" são agrupados
     em "Outros/Indeciso" nos gráficos simplificados.
   - As análises detalhadas continuam disponíveis nas tabelas de frequência.
   - A amostra foi coletada nos pavilhões; portanto, os resultados descrevem
     a amostra pesquisada e não devem ser interpretados automaticamente como
     representativos de todo o eleitorado do DF.

   ========================================================================= */


/* -------------------------------------------------------------------------
   0. CONFIGURAÇÕES
   ------------------------------------------------------------------------- */

options validvarname=any;

%let arquivo = /home/helios_0190/intenções_de_voto_pavilhões.xlsx;
%let outpath = /home/helios_0190/imagens;

ods listing gpath="&outpath." image_dpi=200;
ods graphics on / width=900px height=550px imagefmt=png reset=all;


/* -------------------------------------------------------------------------
   1. IMPORTAÇÃO
   ------------------------------------------------------------------------- */

proc import out=amostra_raw
    datafile="&arquivo."
    dbms=xlsx
    replace;
    getnames=yes;
run;


/* -------------------------------------------------------------------------
   2. LIMPEZA E PADRONIZAÇÃO
   ------------------------------------------------------------------------- */

data amostra;
    set amostra_raw;

    rename
        'Sexo'n                     = sexo
        'Faixa etária'n             = faixa_etaria
        'Faixa de renda familiar'n  = faixa_renda
        'Presidente'n               = presidente
        'Governador'n               = governador
        'Turno'n                    = turno;

    /* Remove linhas totalmente vazias */
    if missing(Timestamp) then delete;

    /* Limpeza de espaços */
    sexo         = strip(sexo);
    faixa_etaria = strip(faixa_etaria);
    faixa_renda  = strip(faixa_renda);
    presidente   = strip(presidente);
    governador   = strip(governador);
    turno        = strip(turno);

    id = _n_;
run;


/* -------------------------------------------------------------------------
   3. PADRONIZAÇÃO DAS VARIÁVEIS SOCIODEMOGRÁFICAS
   ------------------------------------------------------------------------- */

data amostra;
    set amostra;

    length sexo2 $30 idade2 $30 renda2 $40 turno2 $20;

    if missing(sexo) then sexo2='Sem resposta';
    else sexo2=sexo;

    if missing(faixa_etaria) then idade2='Sem resposta';
    else idade2=faixa_etaria;

    if missing(faixa_renda) then renda2='Sem resposta';
    else renda2=faixa_renda;

    if missing(turno) then turno2='Sem resposta';
    else turno2=turno;
run;


/* -------------------------------------------------------------------------
   4. ORDENAÇÃO DAS FAIXAS ETÁRIAS E DE RENDA
   ------------------------------------------------------------------------- */

proc format;
    value idadeord
        0='Sem resposta'
        1='até 18 anos'
        2='19 a 24 anos'
        3='25 a 29 anos'
        4='30 a 34 anos'
        5='35 a 39 anos'
        6='40 a 44 anos'
        7='Acima de 44 anos';

    value rendaord
        0='Sem resposta'
        1='até R$ 1.000'
        2='R$ 1.000 a R$ 2.000'
        3='R$ 2.000 a R$ 5.000'
        4='R$ 5.000 a R$ 10.000'
        5='Mais de R$ 10.000';

    value turnoord
        1='Manhã'
        2='Tarde'
        3='Noite'
        4='Sem resposta';
run;

data amostra;
    set amostra;

    select (idade2);
        when ('Sem resposta')     idade_ord=0;
        when ('até 18 anos')      idade_ord=1;
        when ('19 a 24 anos')     idade_ord=2;
        when ('25 a 29 anos')     idade_ord=3;
        when ('30 a 34 anos')     idade_ord=4;
        when ('35 a 39 anos')     idade_ord=5;
        when ('40 a 44 anos')     idade_ord=6;
        when ('Acima de 44 anos') idade_ord=7;
        otherwise idade_ord=.;
    end;

    select (renda2);
        when ('Sem resposta')         renda_ord=0;
        when ('até R$ 1.000')         renda_ord=1;
        when ('R$ 1.000 a R$ 2.000')  renda_ord=2;
        when ('R$ 2.000 a R$ 5.000')  renda_ord=3;
        when ('R$ 5.000 a R$ 10.000') renda_ord=4;
        when ('Mais de R$ 10.000')    renda_ord=5;
        otherwise renda_ord=.;
    end;

    select (turno2);
        when ('Manhã')  turno_ord=1;
        when ('Tarde')  turno_ord=2;
        when ('Noite')  turno_ord=3;
        otherwise       turno_ord=4;
    end;

    format idade_ord idadeord.
           renda_ord rendaord.
           turno_ord turnoord.;
run;


/* =========================================================================
   5. PERFIL DA AMOSTRA
   ========================================================================= */

title "Perfil da amostra";
proc freq data=amostra;
    tables sexo2 idade_ord renda_ord turno_ord / nocum;
run;
title;


/* Gráfico — sexo */
ods graphics / imagename="v2_perfil_sexo";
title "Perfil da amostra — Sexo";
proc sgplot data=amostra;
    vbar sexo2 / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Sexo";
run;
title;


/* Gráfico — idade */
ods graphics / imagename="v2_perfil_idade";
title "Perfil da amostra — Faixa etária";
proc sgplot data=amostra;
    vbar idade_ord / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Faixa etária" fitpolicy=rotate;
run;
title;


/* Gráfico — renda */
ods graphics / imagename="v2_perfil_renda";
title "Perfil da amostra — Faixa de renda";
proc sgplot data=amostra;
    vbar renda_ord / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Faixa de renda" fitpolicy=rotate;
run;
title;


/* Gráfico — turno */
ods graphics / imagename="v2_perfil_turno";
title "Perfil da amostra — Turno";
proc sgplot data=amostra;
    vbar turno_ord / stat=percent datalabel;
    yaxis label="Percentual (%)" grid;
    xaxis label="Turno";
run;
title;


/* =========================================================================
   6. INTENÇÃO DE VOTO GERAL — DETALHADA
   ========================================================================= */

title "Intenção de voto — Presidente";
proc freq data=amostra order=freq;
    tables presidente / nocum;
run;
title;

title "Intenção de voto — Governador";
proc freq data=amostra order=freq;
    tables governador / nocum;
run;
title;


/* =========================================================================
   7. IDENTIFICAÇÃO AUTOMÁTICA DOS 2 CANDIDATOS MAIS VOTADOS
   =========================================================================
   Branco, Nulo e respostas de incerteza NÃO podem ocupar as posições
   de Top 2. O ranking considera somente candidatos com nome.
   ========================================================================= */

proc freq data=amostra noprint order=freq;
    tables presidente / out=rank_pres;
run;

data rank_pres;
    set rank_pres;
    if missing(presidente) then delete;

    if upcase(strip(presidente)) not in
       ('BRANCO (13)',
        'NULO (14)',
        'NÃO SEI/NÃO QUERO RESPONDER (15)')
    then candidato=1;
    else candidato=0;
run;

proc sort data=rank_pres;
    by descending candidato descending count;
run;

data top_pres;
    set rank_pres;
    if candidato=1;
    if _n_ <= 2;
run;

proc sql noprint;
    select quote(trim(presidente))
    into :pres1-:pres2
    from top_pres;
quit;


/* Governador */

proc freq data=amostra noprint order=freq;
    tables governador / out=rank_gov;
run;

data rank_gov;
    set rank_gov;
    if missing(governador) then delete;

    if upcase(strip(governador)) not in
       ('BRANCO (11)',
        'NULO (12)',
        'NÃO SEI / NÃO QUERO RESPONDER (13)')
    then candidato=1;
    else candidato=0;
run;

proc sort data=rank_gov;
    by descending candidato descending count;
run;

data top_gov;
    set rank_gov;
    if candidato=1;
    if _n_ <= 2;
run;

proc sql noprint;
    select quote(trim(governador))
    into :gov1-:gov2
    from top_gov;
quit;


/* Mostra no log quais foram os Top 2 */
%put ============================================================;
%put TOP 2 PRESIDENTE: &pres1. | &pres2.;
%put TOP 2 GOVERNADOR: &gov1. | &gov2.;
%put ============================================================;


/* =========================================================================
   8. CRIAÇÃO DAS VARIÁVEIS SIMPLIFICADAS PARA OS GRÁFICOS
   =========================================================================
   Categorias exibidas:
       - Candidato 1
       - Candidato 2
       - Branco
       - Nulo
       - Outros/Indeciso

   Isso deixa os gráficos muito mais fáceis de interpretar.
   ========================================================================= */

data amostra;
    set amostra;

    length voto_pres_grp voto_gov_grp $60;

    /* ---------------- PRESIDENTE ---------------- */

    if missing(presidente) then
        voto_pres_grp='Sem resposta';

    else if presidente in (&pres1., &pres2.) then
        voto_pres_grp=presidente;

    else if presidente='Branco (13)' then
        voto_pres_grp='Branco';

    else if presidente='Nulo (14)' then
        voto_pres_grp='Nulo';

    else
        voto_pres_grp='Outros/Indeciso';


    /* ---------------- GOVERNADOR ---------------- */

    if missing(governador) then
        voto_gov_grp='Sem resposta';

    else if governador in (&gov1., &gov2.) then
        voto_gov_grp=governador;

    else if governador='Branco (11)' then
        voto_gov_grp='Branco';

    else if governador='Nulo (12)' then
        voto_gov_grp='Nulo';

    else
        voto_gov_grp='Outros/Indeciso';

run;


/* =========================================================================
   9. INTENÇÃO DE VOTO GERAL — GRÁFICO SIMPLIFICADO
   ========================================================================= */

proc freq data=amostra noprint;
    tables voto_pres_grp / out=geral_pres;
    tables voto_gov_grp  / out=geral_gov;
run;


/* Presidente */
ods graphics / imagename="v2_presidente_geral";
title "Intenção de voto — Presidente";
title2 "Top 2 candidatos + Branco + Nulo";
proc sgplot data=geral_pres;
    hbar voto_pres_grp / response=count stat=sum
         datalabel categoryorder=respdesc;
    xaxis label="Número de respostas" grid;
    yaxis label="Resposta";
run;
title;


/* Governador */
ods graphics / imagename="v2_governador_geral";
title "Intenção de voto — Governador";
title2 "Top 2 candidatos + Branco + Nulo";
proc sgplot data=geral_gov;
    hbar voto_gov_grp / response=count stat=sum
         datalabel categoryorder=respdesc;
    xaxis label="Número de respostas" grid;
    yaxis label="Resposta";
run;
title;


/* =========================================================================
   10. INTENÇÃO DE VOTO POR SEXO
   =========================================================================
   O PCT_ROW mostra a composição do voto DENTRO de cada sexo.
   ========================================================================= */

proc freq data=amostra noprint;
    tables sexo2*voto_pres_grp / out=pres_sexo outpct chisq;
    tables sexo2*voto_gov_grp  / out=gov_sexo  outpct chisq;
run;


/* Presidente x Sexo */
ods graphics / imagename="v2_presidente_sexo";
title "Intenção de voto para Presidente por Sexo";
title2 "Percentual dentro de cada sexo";
proc sgplot data=pres_sexo;
    vbar sexo2 / response=pct_row
         group=voto_pres_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro do sexo (%)" grid values=(0 to 100 by 20);
    xaxis label="Sexo";
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* Governador x Sexo */
ods graphics / imagename="v2_governador_sexo";
title "Intenção de voto para Governador por Sexo";
title2 "Percentual dentro de cada sexo";
proc sgplot data=gov_sexo;
    vbar sexo2 / response=pct_row
         group=voto_gov_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro do sexo (%)" grid values=(0 to 100 by 20);
    xaxis label="Sexo";
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* =========================================================================
   11. INTENÇÃO DE VOTO POR FAIXA ETÁRIA
   ========================================================================= */

proc freq data=amostra noprint;
    tables idade_ord*voto_pres_grp / out=pres_idade outpct chisq;
    tables idade_ord*voto_gov_grp  / out=gov_idade  outpct chisq;
run;


/* Presidente x Idade */
ods graphics / imagename="v2_presidente_idade";
title "Intenção de voto para Presidente por Faixa Etária";
title2 "Percentual dentro de cada faixa etária";
proc sgplot data=pres_idade;
    vbar idade_ord / response=pct_row
         group=voto_pres_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid values=(0 to 100 by 20);
    xaxis label="Faixa etária" fitpolicy=rotate;
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* Governador x Idade */
ods graphics / imagename="v2_governador_idade";
title "Intenção de voto para Governador por Faixa Etária";
title2 "Percentual dentro de cada faixa etária";
proc sgplot data=gov_idade;
    vbar idade_ord / response=pct_row
         group=voto_gov_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid values=(0 to 100 by 20);
    xaxis label="Faixa etária" fitpolicy=rotate;
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* =========================================================================
   12. INTENÇÃO DE VOTO POR FAIXA DE RENDA
   ========================================================================= */

proc freq data=amostra noprint;
    tables renda_ord*voto_pres_grp / out=pres_renda outpct chisq;
    tables renda_ord*voto_gov_grp  / out=gov_renda  outpct chisq;
run;


/* Presidente x Renda */
ods graphics / imagename="v2_presidente_renda";
title "Intenção de voto para Presidente por Faixa de Renda";
title2 "Percentual dentro de cada faixa de renda";
proc sgplot data=pres_renda;
    vbar renda_ord / response=pct_row
         group=voto_pres_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid values=(0 to 100 by 20);
    xaxis label="Faixa de renda" fitpolicy=rotate;
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* Governador x Renda */
ods graphics / imagename="v2_governador_renda";
title "Intenção de voto para Governador por Faixa de Renda";
title2 "Percentual dentro de cada faixa de renda";
proc sgplot data=gov_renda;
    vbar renda_ord / response=pct_row
         group=voto_gov_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro da faixa (%)" grid values=(0 to 100 by 20);
    xaxis label="Faixa de renda" fitpolicy=rotate;
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* =========================================================================
   13. INTENÇÃO DE VOTO POR TURNO
   ========================================================================= */

proc freq data=amostra noprint;
    tables turno_ord*voto_pres_grp / out=pres_turno outpct chisq;
    tables turno_ord*voto_gov_grp  / out=gov_turno  outpct chisq;
run;


/* Presidente x Turno */
ods graphics / imagename="v2_presidente_turno";
title "Intenção de voto para Presidente por Turno";
title2 "Percentual dentro de cada turno";
proc sgplot data=pres_turno;
    vbar turno_ord / response=pct_row
         group=voto_pres_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro do turno (%)" grid values=(0 to 100 by 20);
    xaxis label="Turno";
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* Governador x Turno */
ods graphics / imagename="v2_governador_turno";
title "Intenção de voto para Governador por Turno";
title2 "Percentual dentro de cada turno";
proc sgplot data=gov_turno;
    vbar turno_ord / response=pct_row
         group=voto_gov_grp
         groupdisplay=stack;
    yaxis label="Percentual dentro do turno (%)" grid values=(0 to 100 by 20);
    xaxis label="Turno";
    keylegend / title="Intenção de voto" location=outside;
run;
title;


/* =========================================================================
   14. TABELAS DE PERCENTUAL POR SEXO E IDADE
   =========================================================================
   Além dos gráficos, estas tabelas são importantes para a interpretação.
   PCT_ROW = percentual dentro do grupo.
   ========================================================================= */

title "Presidente — percentual dentro de cada sexo";
proc freq data=amostra;
    tables sexo2*voto_pres_grp / norow nocol;
run;
title;

title "Governador — percentual dentro de cada sexo";
proc freq data=amostra;
    tables sexo2*voto_gov_grp / norow nocol;
run;
title;

title "Presidente — percentual dentro de cada faixa etária";
proc freq data=amostra;
    tables idade_ord*voto_pres_grp / norow nocol;
run;
title;

title "Governador — percentual dentro de cada faixa etária";
proc freq data=amostra;
    tables idade_ord*voto_gov_grp / norow nocol;
run;
title;


/* =========================================================================
   15. TESTES QUI-QUADRADO
   =========================================================================
   H0: não existe associação entre o perfil e a intenção de voto.
   H1: existe associação.

   Atenção:
   - p < 0,05 sugere associação estatisticamente significativa.
   - O teste não prova causalidade.
   - Com grupos pequenos, especialmente algumas faixas etárias, os
     pressupostos do qui-quadrado podem ficar comprometidos.
   ========================================================================= */

title "Qui-quadrado — Presidente x Sexo";
proc freq data=amostra;
    tables sexo2*voto_pres_grp / chisq;
run;
title;

title "Qui-quadrado — Presidente x Faixa Etária";
proc freq data=amostra;
    tables idade_ord*voto_pres_grp / chisq;
run;
title;

title "Qui-quadrado — Presidente x Renda";
proc freq data=amostra;
    tables renda_ord*voto_pres_grp / chisq;
run;
title;

title "Qui-quadrado — Presidente x Turno";
proc freq data=amostra;
    tables turno_ord*voto_pres_grp / chisq;
run;
title;


title "Qui-quadrado — Governador x Sexo";
proc freq data=amostra;
    tables sexo2*voto_gov_grp / chisq;
run;
title;

title "Qui-quadrado — Governador x Faixa Etária";
proc freq data=amostra;
    tables idade_ord*voto_gov_grp / chisq;
run;
title;

title "Qui-quadrado — Governador x Renda";
proc freq data=amostra;
    tables renda_ord*voto_gov_grp / chisq;
run;
title;

title "Qui-quadrado — Governador x Turno";
proc freq data=amostra;
    tables turno_ord*voto_gov_grp / chisq;
run;
title;


/* =========================================================================
   16. NÃO-RESPOSTA
   ========================================================================= */

data amostra;
    set amostra;

    if missing(presidente) then resp_pres='Não respondeu';
    else resp_pres='Respondeu';

    if missing(governador) then resp_gov='Não respondeu';
    else resp_gov='Respondeu';
run;

title "Não-resposta — Presidente";
proc freq data=amostra;
    tables resp_pres / nocum;
run;
title;

title "Não-resposta — Governador";
proc freq data=amostra;
    tables resp_gov / nocum;
run;
title;

title "Não-resposta para Presidente por Sexo";
proc freq data=amostra;
    tables sexo2*resp_pres / chisq;
run;
title;

title "Não-resposta para Governador por Sexo";
proc freq data=amostra;
    tables sexo2*resp_gov / chisq;
run;
title;


/* =========================================================================
   17. INTERVALOS DE CONFIANÇA — INTENÇÃO DE VOTO GERAL
   =========================================================================
   Aqui o cálculo é feito sobre os votos válidos de cada cargo.
   O IC é calculado para cada categoria da intenção de voto.
   ========================================================================= */

proc freq data=amostra noprint;
    tables presidente / out=ic_pres;
    tables governador / out=ic_gov;
run;

proc sql noprint;
    select sum(count) into :n_pres_valid
    from ic_pres
    where not missing(presidente);

    select sum(count) into :n_gov_valid
    from ic_gov
    where not missing(governador);
quit;

data ic_pres;
    set ic_pres;
    if missing(presidente) then delete;

    p_hat=count/&n_pres_valid.;
    se=sqrt(p_hat*(1-p_hat)/&n_pres_valid.);
    tcrit=tinv(0.975,&n_pres_valid.-1);

    limite_inferior=max(0,p_hat-tcrit*se);
    limite_superior=min(1,p_hat+tcrit*se);

    percentual=p_hat*100;
    ic_inferior=limite_inferior*100;
    ic_superior=limite_superior*100;
run;

data ic_gov;
    set ic_gov;
    if missing(governador) then delete;

    p_hat=count/&n_gov_valid.;
    se=sqrt(p_hat*(1-p_hat)/&n_gov_valid.);
    tcrit=tinv(0.975,&n_gov_valid.-1);

    limite_inferior=max(0,p_hat-tcrit*se);
    limite_superior=min(1,p_hat+tcrit*se);

    percentual=p_hat*100;
    ic_inferior=limite_inferior*100;
    ic_superior=limite_superior*100;
run;

title "Intervalos de confiança — Presidente";
proc print data=ic_pres noobs;
    var presidente count percentual ic_inferior ic_superior;
    format percentual ic_inferior ic_superior 6.2;
run;
title;

title "Intervalos de confiança — Governador";
proc print data=ic_gov noobs;
    var governador count percentual ic_inferior ic_superior;
    format percentual ic_inferior ic_superior 6.2;
run;
title;


/* =========================================================================
   18. RESUMO FINAL NO LOG
   ========================================================================= */

data _null_;
    put "============================================================";
    put "ANÁLISE V2 CONCLUÍDA";
    put "Top 2 Presidente: &pres1. | &pres2.";
    put "Top 2 Governador: &gov1. | &gov2.";
    put "============================================================";
run;
