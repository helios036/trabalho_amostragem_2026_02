/* =========================================================================
   CONTINUAÇÃO DO SEU CÓDIGO (a partir da seção 5)
   Equivale ao gerar_graficos.py. Rode depois das seções 0 a 4 que você enviou.
   ========================================================================= */

/* -------------------------------------------------------------------------
   5. OPÇÕES DE TRATAMENTO DOS AUSENTES NAS VARIÁVEIS DE VOTO
   0 = como no .py: linhas sem voto ficam fora das estimativas (n = respondentes)
   1 = linhas sem voto viram "Sem resposta" (n = 400, como está no relatório)
   ------------------------------------------------------------------------- */

%let incluir_ausentes = 0;


/* -------------------------------------------------------------------------
   6. LIMPEZA DOS NOMES DOS CANDIDATOS
   Remove espaços nas pontas e o sufixo " (n)" (ex.: "Lula (5)" -> "Lula")
   ------------------------------------------------------------------------- */

data amostra;
    set amostra;

    if not missing(presidente) then
        presidente = strip(prxchange('s/\s*\(\d+\)\s*$//', 1, strip(presidente)));
    if not missing(governador) then
        governador = strip(prxchange('s/\s*\(\d+\)\s*$//', 1, strip(governador)));

    if &incluir_ausentes. = 1 then do;
        if missing(presidente) then presidente = 'Sem resposta';
        if missing(governador) then governador = 'Sem resposta';
    end;
run;


/* -------------------------------------------------------------------------
   7. VARIÁVEIS NUMÉRICAS DE ORDENAÇÃO (para os eixos dos gráficos)
   ------------------------------------------------------------------------- */

proc format;
    value sexoord
        1='Masculino'
        2='Feminino';
run;

data amostra;
    set amostra;

    select (sexo2);
        when ('Masculino') sexo_ord = 1;
        when ('Feminino')  sexo_ord = 2;
        otherwise          sexo_ord = .;
    end;

    select (idade2);
        when ('Sem resposta')     idade_ord = 0;
        when ('até 18 anos')      idade_ord = 1;
        when ('19 a 24 anos')     idade_ord = 2;
        when ('25 a 29 anos')     idade_ord = 3;
        when ('30 a 34 anos')     idade_ord = 4;
        when ('35 a 39 anos')     idade_ord = 5;
        when ('40 a 44 anos')     idade_ord = 6;
        when ('Acima de 44 anos') idade_ord = 7;
        otherwise                 idade_ord = .;
    end;

    select (renda2);
        when ('Sem resposta')          renda_ord = 0;
        when ('até R$ 1.000')          renda_ord = 1;
        when ('R$ 1.000 a R$ 2.000')   renda_ord = 2;
        when ('R$ 2.000 a R$ 5.000')   renda_ord = 3;
        when ('R$ 5.000 a R$ 10.000')  renda_ord = 4;
        when ('Mais de R$ 10.000')     renda_ord = 5;
        otherwise                      renda_ord = .;
    end;

    select (turno2);
        when ('Manhã')        turno_ord = 1;
        when ('Tarde')        turno_ord = 2;
        when ('Noite')        turno_ord = 3;
        when ('Sem resposta') turno_ord = 4;
        otherwise             turno_ord = .;
    end;

    format sexo_ord sexoord. idade_ord idadeord. renda_ord rendaord. turno_ord turnoord.;
run;


/* -------------------------------------------------------------------------
   8. GRUPO "OUTROS" (< 1% das respostas não ausentes)
   Branco, Nulo, Sem resposta e Não sei NUNCA entram em "Outros".
   Cria <var>_grp.
   ------------------------------------------------------------------------- */

%macro agrupar_outros(var=);

    proc freq data=amostra noprint;
        tables &var. / out=_f_&var.(drop=percent);
    run;

    proc sql noprint;
        select sum(count) into :nv trimmed from _f_&var.;
    quit;

    data _f_&var.;
        set _f_&var.;
        length &var._grp $60;
        if &var. in ('Branco','Nulo','Sem resposta') or index(&var.,'Não sei')=1
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


/* -------------------------------------------------------------------------
   9. PALETAS DE CORES E ORDEM DA LEGENDA
   Candidatos em ordem alfabética, depois "Outros", depois o bloco de não-voto.
   ------------------------------------------------------------------------- */

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
10|Sem resposta|CX595959
11|Não sei/não quero responder|CX404040
;
run;

data paleta_gov;
    length id $4 value $40 fillcolor $9;
    infile datalines dlm='|' dsd truncover;
    input ord value :$40. fillcolor :$9.;
    id = 'gov';
    datalines;
1|Celina Leão|CXD4AC0D
2|Kiko Caputo|CXE8821E
3|Leandro Grass|CXE03C31
4|Paula Belmonte|CX1F6FD1
5|Ricardo Cappelli|CX1B998B
6|Outros|CXC2A878
7|Branco|CXBFBFBF
8|Nulo|CX808080
9|Sem resposta|CX595959
10|Não sei / Não quero responder|CX404040
;
run;

/* Attribute map usado por todos os gráficos de candidatos */
data attrmap;
    set paleta_pres paleta_gov;
    linecolor = 'white';
    drop ord;
run;

/* Cor única dos gráficos de perfil */
%let cor_neutra = CX3B6FA0;


/* -------------------------------------------------------------------------
   10. MACROS DE GRÁFICO
   ------------------------------------------------------------------------- */

/* 10.1 Perfil (barras simples com % no topo) */
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

/* 10.2 Intenção de voto com IC 95% (Cochran, divisor n-1, percentil t) */
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

    proc sort data=_ic; by pct; run;   /* maior no topo do gráfico */

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

/* 10.3 Barras empilhadas: % de cada voto dentro de cada categoria */
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


/* -------------------------------------------------------------------------
   11. EXECUÇÃO
   ------------------------------------------------------------------------- */

/* Tamanhos de n */
proc sql;
    select count(*)            as n_nominal,
           count(presidente)   as n_valido_presidente,
           count(governador)   as n_valido_governador
    from amostra;
quit;

/* Perfil */
%grafico_perfil(ord=sexo_ord,  titulo=Distribuição por Sexo,                  xlabel=Sexo,           nome=perfil_sexo,   w=700);
%grafico_perfil(ord=idade_ord, titulo=Distribuição por Faixa Etária,          xlabel=Faixa etária,   nome=perfil_etaria);
%grafico_perfil(ord=renda_ord, titulo=Distribuição por Faixa de Renda Familiar, xlabel=Faixa de renda, nome=perfil_renda);
%grafico_perfil(ord=turno_ord, titulo=Distribuição por Turno de Coleta,       xlabel=Turno,          nome=perfil_turno,  w=700);

/* Intenção de voto com IC 95% */
%grafico_ic(grp=presidente_grp, attrid=pres,
            titulo=Intenção de voto - Presidente (%) com IC 95%, nome=voto_presidente_ic);
%grafico_ic(grp=governador_grp, attrid=gov,
            titulo=Intenção de voto - Governador (%) com IC 95%, nome=voto_governador_ic);

/* Cruzamentos por subgrupo */
%grafico_empilhado(ord=renda_ord, grp=presidente_grp, pal=paleta_pres, attrid=pres,
    titulo=Presidente por Faixa de Renda (% dentro de cada faixa),
    xlabel=Faixa de renda, nome=presidente_por_renda);
%grafico_empilhado(ord=idade_ord, grp=presidente_grp, pal=paleta_pres, attrid=pres,
    titulo=Presidente por Faixa Etária (% dentro de cada faixa),
    xlabel=Faixa etária, nome=presidente_por_etaria);
%grafico_empilhado(ord=turno_ord, grp=presidente_grp, pal=paleta_pres, attrid=pres,
    titulo=Presidente por Turno (% dentro de cada turno),
    xlabel=Turno, nome=presidente_por_turno);

%grafico_empilhado(ord=renda_ord, grp=governador_grp, pal=paleta_gov, attrid=gov,
    titulo=Governador por Faixa de Renda (% dentro de cada faixa),
    xlabel=Faixa de renda, nome=governador_por_renda);
%grafico_empilhado(ord=idade_ord, grp=governador_grp, pal=paleta_gov, attrid=gov,
    titulo=Governador por Faixa Etária (% dentro de cada faixa),
    xlabel=Faixa etária, nome=governador_por_etaria);
%grafico_empilhado(ord=turno_ord, grp=governador_grp, pal=paleta_gov, attrid=gov,
    titulo=Governador por Turno (% dentro de cada turno),
    xlabel=Turno, nome=governador_por_turno);

ods graphics off;
