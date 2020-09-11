CREATE TABLE av_geschaeftskontrolle.amo (
	id serial NOT NULL,
	auftrag_id int4 NOT NULL,
	amo_nr varchar NULL,
	CONSTRAINT amo_pkey PRIMARY KEY (id),
	CONSTRAINT amo_auftrag_id_fkey FOREIGN KEY (auftrag_id) REFERENCES av_geschaeftskontrolle.auftrag(id) MATCH FULL
);

-- Drop table

-- DROP TABLE av_geschaeftskontrolle.auftrag;

CREATE TABLE av_geschaeftskontrolle.auftrag (
	id serial NOT NULL,
	projekt_id int4 NOT NULL,
	"name" varchar NOT NULL,
	kosten numeric(20,2) NULL,
	mwst float8 NULL,
	verguetungsart_id int4 NULL,
	unternehmer_id int4 NOT NULL,
	datum_start date NULL,
	datum_ende date NULL,
	datum_abschluss date NULL,
	geplant bool NULL,
	bemerkung varchar NULL,
	CONSTRAINT auftrag_pkey PRIMARY KEY (id),
	CONSTRAINT auftrag_projekt_id_fkey FOREIGN KEY (projekt_id) REFERENCES av_geschaeftskontrolle.projekt(id) MATCH FULL,
	CONSTRAINT auftrag_unternehmer_id_fkey FOREIGN KEY (unternehmer_id) REFERENCES av_geschaeftskontrolle.unternehmer(id) MATCH FULL,
	CONSTRAINT auftrag_verguetungsart_id FOREIGN KEY (verguetungsart_id) REFERENCES av_geschaeftskontrolle.verguetungsart(id) MATCH FULL
);

-- Table Triggers

-- DROP TRIGGER update_planzahlungskosten ON av_geschaeftskontrolle.auftrag;

CREATE TRIGGER update_planzahlungskosten AFTER
UPDATE
    ON
    av_geschaeftskontrolle.auftrag FOR EACH ROW EXECUTE PROCEDURE av_geschaeftskontrolle.calculate_budget_payment_from_total_cost();


-- Drop table

-- DROP TABLE av_geschaeftskontrolle.konto;

CREATE TABLE av_geschaeftskontrolle.konto (
	id serial NOT NULL,
	nr int4 NOT NULL,
	"name" varchar NULL,
	bemerkung varchar NULL,
	CONSTRAINT konto_nr_key UNIQUE (id, nr),
	CONSTRAINT konto_pkey PRIMARY KEY (id)
);



-- Drop table

-- DROP TABLE av_geschaeftskontrolle.perimeter;

CREATE TABLE av_geschaeftskontrolle.perimeter (
	id serial NOT NULL,
	projekt_id int4 NOT NULL,
	perimeter geometry(MULTIPOLYGON, 2056) NULL,
	CONSTRAINT perimeter_pkey PRIMARY KEY (id),
	CONSTRAINT perimeter_projekt_id_fkey FOREIGN KEY (projekt_id) REFERENCES av_geschaeftskontrolle.projekt(id) MATCH FULL
);



-- Drop table

-- DROP TABLE av_geschaeftskontrolle.plankostenkonto;

CREATE TABLE av_geschaeftskontrolle.plankostenkonto (
	id serial NOT NULL,
	konto_id int4 NOT NULL,
	budget numeric(20,2) NOT NULL,
	jahr int4 NOT NULL,
	bemerkung varchar NULL,
	CONSTRAINT plankostenkonto_konto_id_jahr_key UNIQUE (konto_id, jahr),
	CONSTRAINT plankostenkonto_pkey PRIMARY KEY (id),
	CONSTRAINT plankostenkonto_konto_id_fkey FOREIGN KEY (konto_id) REFERENCES av_geschaeftskontrolle.konto(id) MATCH FULL
);



-- Drop table

-- DROP TABLE av_geschaeftskontrolle.planzahlung;

CREATE TABLE av_geschaeftskontrolle.planzahlung (
	id serial NOT NULL,
	auftrag_id int4 NOT NULL,
	prozent numeric(6,3) NULL,
	kosten numeric(20,2) NULL,
	mwst float8 NULL,
	rechnungsjahr int4 NULL,
	bemerkung varchar NULL,
	CONSTRAINT planzahlung_pkey PRIMARY KEY (id),
	CONSTRAINT planzahlung_positiv_prozent CHECK ((prozent > (0)::numeric)),
	CONSTRAINT planzahlung_projekt_id_fkey FOREIGN KEY (auftrag_id) REFERENCES av_geschaeftskontrolle.auftrag(id) MATCH FULL
);

-- Table Triggers

-- DROP TRIGGER update_kosten ON av_geschaeftskontrolle.planzahlung;

CREATE TRIGGER update_kosten BEFORE
INSERT
    OR
UPDATE
    ON
    av_geschaeftskontrolle.planzahlung FOR EACH ROW EXECUTE PROCEDURE av_geschaeftskontrolle.calculate_order_costs_from_percentage();



-- Drop table

-- DROP TABLE av_geschaeftskontrolle.projekt;

CREATE TABLE av_geschaeftskontrolle.projekt (
	id serial NOT NULL,
	konto_id int4 NOT NULL,
	"name" varchar NOT NULL,
	kosten numeric(20,2) NULL,
	mwst float8 NULL,
	datum_start date NOT NULL,
	datum_ende date NULL,
	bemerkung varchar NULL,
	CONSTRAINT projekt_pkey PRIMARY KEY (id),
	CONSTRAINT projekt_konto_id_fkey FOREIGN KEY (konto_id) REFERENCES av_geschaeftskontrolle.konto(id) MATCH FULL
);



-- Drop table

-- DROP TABLE av_geschaeftskontrolle.rechnung;

CREATE TABLE av_geschaeftskontrolle.rechnung (
	id serial NOT NULL,
	auftrag_id int4 NOT NULL,
	kosten numeric(20,2) NULL,
	mwst float8 NULL,
	datum_eingang date NULL,
	datum_ausgang date NULL,
	rechnungsjahr int4 NULL,
	bemerkung varchar NULL,
	CONSTRAINT rechnung_pkey PRIMARY KEY (id),
	CONSTRAINT rechnung_auftrag_id_fkey FOREIGN KEY (auftrag_id) REFERENCES av_geschaeftskontrolle.auftrag(id) MATCH FULL
);


-- Drop table

-- DROP TABLE av_geschaeftskontrolle.rechnungsjahr;

CREATE TABLE av_geschaeftskontrolle.rechnungsjahr (
	id serial NOT NULL,
	jahr int4 NOT NULL
);
-- Drop table

-- DROP TABLE av_geschaeftskontrolle.unternehmer;

CREATE TABLE av_geschaeftskontrolle.unternehmer (
	id serial NOT NULL,
	firma varchar NOT NULL,
	uid int4 NULL,
	nachname varchar NULL,
	vorname varchar NULL,
	strasse varchar NULL,
	hausnummer varchar NULL,
	plz int4 NULL,
	ortschaft varchar NULL,
	bemerkung varchar NULL,
	CONSTRAINT unternehmer_pkey PRIMARY KEY (id)
);


-- Drop table

-- DROP TABLE av_geschaeftskontrolle.verguetungsart;

CREATE TABLE av_geschaeftskontrolle.verguetungsart (
	id serial NOT NULL,
	art varchar NOT NULL,
	CONSTRAINT verguetungsart_pkey PRIMARY KEY (id)
);


CREATE OR REPLACE VIEW av_geschaeftskontrolle.vr_firma_verpflichtungen
AS SELECT 
        CASE
            WHEN foo.firma IS NULL THEN bar.firma
            ELSE foo.firma
        END AS firma, 
        CASE
            WHEN foo.jahr IS NULL THEN bar.jahr::double precision
            ELSE foo.jahr
        END AS jahr, 
    foo.kosten_vertrag_inkl, bar.kosten_bezahlt_inkl
   FROM ( SELECT a.kosten_vertrag_inkl, a.unternehmer_id, a.jahr, un.firma
           FROM ( SELECT sum(auf.kosten::double precision * (1::double precision + auf.mwst / 100::double precision)) AS kosten_vertrag_inkl, 
                    auf.unternehmer_id, 
                    date_part('year'::text, auf.datum_start) AS jahr
                   FROM av_geschaeftskontrolle.auftrag auf
                  WHERE auf.geplant = false
                  GROUP BY auf.unternehmer_id, date_part('year'::text, auf.datum_start)) a, 
            av_geschaeftskontrolle.unternehmer un
          WHERE a.unternehmer_id = un.id) foo
   FULL JOIN ( SELECT sum(a.kosten_bezahlt_inkl) AS kosten_bezahlt_inkl, a.jahr, 
            auf.unternehmer_id, un.firma
           FROM ( SELECT sum(rechnung.kosten::double precision * (1::double precision + rechnung.mwst / 100::double precision)) AS kosten_bezahlt_inkl, 
                    rechnung.auftrag_id, rechnung.rechnungsjahr AS jahr
                   FROM av_geschaeftskontrolle.rechnung
                  GROUP BY rechnung.auftrag_id, rechnung.rechnungsjahr) a, 
            av_geschaeftskontrolle.auftrag auf, 
            av_geschaeftskontrolle.unternehmer un
          WHERE a.auftrag_id = auf.id AND auf.unternehmer_id = un.id
          GROUP BY auf.unternehmer_id, un.firma, a.jahr) bar ON foo.unternehmer_id = bar.unternehmer_id AND foo.jahr = bar.jahr::double precision;


CREATE OR REPLACE VIEW av_geschaeftskontrolle.vr_kontr_planprozent
AS SELECT a.name AS auf_name, d.firma, b.name AS proj_name, c.nr AS konto_nr, 
    a.sum_planprozent
   FROM ( SELECT sum(pz.kosten) AS sum_plankosten_exkl, auf.name, 
            sum(pz.prozent) AS sum_planprozent, auf.projekt_id, 
            auf.unternehmer_id
           FROM av_geschaeftskontrolle.planzahlung pz, 
            av_geschaeftskontrolle.auftrag auf, 
            av_geschaeftskontrolle.projekt proj
          WHERE pz.auftrag_id = auf.id AND auf.projekt_id = proj.id AND auf.datum_abschluss IS NULL OR btrim(auf.datum_abschluss::text, ''::text) = ''::text
          GROUP BY auf.id) a, av_geschaeftskontrolle.projekt b, 
    av_geschaeftskontrolle.konto c, av_geschaeftskontrolle.unternehmer d
  WHERE a.projekt_id = b.id AND c.id = b.konto_id AND a.unternehmer_id = d.id
  ORDER BY b.name, a.name;


CREATE OR REPLACE VIEW av_geschaeftskontrolle.vr_laufende_auftraege
AS SELECT af.auf_id, af.auftrag_name, af.firma, af.geplant, af.proj_id, 
    af.projekt_name, af.konto, af.datum_start, af.datum_ende, af.verguetungsart, 
    af.kosten_exkl, af.mwst, af.kosten_inkl, af.bezahlt, af.ausstehend, 
    am.id_auftrag, am.amo_nr
   FROM ( SELECT a.auf_id, a.auftrag_name, a.firma, a.geplant, a.proj_id, 
            a.projekt_name, a.konto, a.datum_start, a.datum_ende, 
            v.verguetungsart, a.kosten_exkl, a.mwst, a.kosten_inkl, a.bezahlt, 
            a.ausstehend
           FROM ( SELECT auftrag.auf_id, auftrag.auftrag_name, auftrag.firma, 
                    auftrag.geplant, auftrag.verguetungsart_id, auftrag.proj_id, 
                    auftrag.projekt_name, auftrag.konto, auftrag.datum_start, 
                    auftrag.datum_ende, auftrag.kosten_exkl, auftrag.mwst, 
                    auftrag.kosten_inkl, rechnung.bezahlt, 
                    auftrag.kosten_inkl - 
                        CASE
                            WHEN rechnung.bezahlt IS NULL THEN 0::double precision
                            ELSE rechnung.bezahlt
                        END AS ausstehend
                   FROM ( SELECT auf.id AS auf_id, auf.name AS auftrag_name, 
                            u.firma, auf.geplant, auf.verguetungsart_id, 
                            proj.id AS proj_id, proj.name AS projekt_name, 
                            konto.nr::text AS konto, auf.datum_start, 
                            auf.datum_ende, auf.kosten AS kosten_exkl, auf.mwst, 
                            auf.kosten::double precision * (1::double precision + auf.mwst / 100::double precision) AS kosten_inkl
                           FROM av_geschaeftskontrolle.auftrag auf, 
                            av_geschaeftskontrolle.projekt proj, 
                            av_geschaeftskontrolle.konto konto, 
                            av_geschaeftskontrolle.unternehmer u
                          WHERE auf.projekt_id = proj.id AND proj.konto_id = konto.id AND auf.unternehmer_id = u.id AND auf.datum_abschluss IS NULL OR btrim(auf.datum_abschluss::text, ''::text) = ''::text) auftrag
              LEFT JOIN ( SELECT sum(rechnung_1.kosten::double precision * (1::double precision + rechnung_1.mwst / 100::double precision)) AS bezahlt, 
                            rechnung_1.auftrag_id
                           FROM av_geschaeftskontrolle.rechnung rechnung_1
                          GROUP BY rechnung_1.auftrag_id) rechnung ON rechnung.auftrag_id = auftrag.auf_id) a
      LEFT JOIN ( SELECT verguetungsart.id, 
                    verguetungsart.art AS verguetungsart
                   FROM av_geschaeftskontrolle.verguetungsart) v ON a.verguetungsart_id = v.id) af
   LEFT JOIN ( SELECT ao.auftrag_id AS id_auftrag, 
            array_to_string(array_agg(ao.amo_nr), ', '::text) AS amo_nr
           FROM ( SELECT amo.id, amo.auftrag_id, amo.amo_nr
                   FROM av_geschaeftskontrolle.amo
                  ORDER BY amo.amo_nr) ao
          GROUP BY ao.auftrag_id) am ON af.auf_id = am.id_auftrag
  ORDER BY af.datum_start, af.auftrag_name;


CREATE OR REPLACE VIEW av_geschaeftskontrolle.vr_zahlungsplan_19_22
AS SELECT foo.auf_name, foo.auf_geplant, proj.name AS proj_name, 
    konto.nr AS konto, foo.auf_start, foo.auf_ende, foo.auf_abschluss, 
    foo.plan_summe_a, foo.plan_prozent_a, foo.re_summe_a, 
    foo.re_summe_a / foo.auf_summe * 100::double precision AS re_prozent_a, 
    foo.plan_summe_b, foo.plan_prozent_b, foo.plan_summe_c, foo.plan_prozent_c, 
    foo.plan_summe_d, foo.plan_prozent_d, foo.a_id, foo.projekt_id
   FROM ( SELECT a.auf_name, a.auf_geplant, a.auf_start, a.auf_ende, 
            a.auf_abschluss, a.auf_summe, a.plan_summe_a, a.plan_prozent_a, 
            a.a_id, a.projekt_id, r.re_summe_a, r.r_id, b.plan_summe_b, 
            b.plan_prozent_b, b.b_id, c.plan_summe_c, c.plan_prozent_c, c.c_id, 
            d.plan_summe_d, d.plan_prozent_d, d.d_id
           FROM ( SELECT auf.name AS auf_name, auf.geplant AS auf_geplant, 
                    auf.datum_start AS auf_start, auf.datum_ende AS auf_ende, 
                    auf.datum_abschluss AS auf_abschluss, 
                    auf.kosten::double precision * (1::double precision + auf.mwst / 100::double precision) AS auf_summe, 
                    sum(pz.kosten::double precision * (1::double precision + pz.mwst / 100::double precision)) AS plan_summe_a, 
                    sum(pz.prozent) AS plan_prozent_a, auf.id AS a_id, 
                    auf.projekt_id
                   FROM av_geschaeftskontrolle.planzahlung pz, 
                    av_geschaeftskontrolle.auftrag auf
                  WHERE pz.auftrag_id = auf.id AND pz.rechnungsjahr = 2019
                  GROUP BY auf.id) a
      LEFT JOIN ( SELECT sum(re.kosten::double precision * (1::double precision + re.mwst / 100::double precision)) AS re_summe_a, 
                    auf.id AS r_id
                   FROM av_geschaeftskontrolle.rechnung re, 
                    av_geschaeftskontrolle.auftrag auf
                  WHERE re.auftrag_id = auf.id AND re.rechnungsjahr = 2019
                  GROUP BY auf.id) r ON a.a_id = r.r_id
   LEFT JOIN ( SELECT sum(pz.kosten::double precision * (1::double precision + pz.mwst / 100::double precision)) AS plan_summe_b, 
               sum(pz.prozent) AS plan_prozent_b, auf.id AS b_id
              FROM av_geschaeftskontrolle.planzahlung pz, 
               av_geschaeftskontrolle.auftrag auf
             WHERE pz.auftrag_id = auf.id AND pz.rechnungsjahr = 2020
             GROUP BY auf.id) b ON a.a_id = b.b_id
   LEFT JOIN ( SELECT sum(pz.kosten::double precision * (1::double precision + pz.mwst / 100::double precision)) AS plan_summe_c, 
          sum(pz.prozent) AS plan_prozent_c, auf.id AS c_id
         FROM av_geschaeftskontrolle.planzahlung pz, 
          av_geschaeftskontrolle.auftrag auf
        WHERE pz.auftrag_id = auf.id AND pz.rechnungsjahr = 2021
        GROUP BY auf.id) c ON a.a_id = c.c_id
   LEFT JOIN ( SELECT sum(pz.kosten::double precision * (1::double precision + pz.mwst / 100::double precision)) AS plan_summe_d, 
     sum(pz.prozent) AS plan_prozent_d, auf.id AS d_id
    FROM av_geschaeftskontrolle.planzahlung pz, 
     av_geschaeftskontrolle.auftrag auf
   WHERE pz.auftrag_id = auf.id AND pz.rechnungsjahr = 2022
   GROUP BY auf.id) d ON a.a_id = d.d_id) foo, 
    av_geschaeftskontrolle.projekt proj, av_geschaeftskontrolle.konto konto
  WHERE foo.projekt_id = proj.id AND proj.konto_id = konto.id
  ORDER BY konto.nr, foo.auf_name;



CREATE OR REPLACE FUNCTION av_geschaeftskontrolle.calculate_budget_payment_from_total_cost()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ 
 BEGIN

UPDATE av_geschaeftskontrolle.planzahlung SET kosten = auf.kosten * (prozent/100) 
FROM av_geschaeftskontrolle.auftrag as auf
WHERE auf.id = auftrag_id;
 
 RETURN NULL;
 END;$function$
;


CREATE OR REPLACE FUNCTION av_geschaeftskontrolle.calculate_order_costs_from_percentage()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$ DECLARE gesamtkosten DOUBLE PRECISION;
 BEGIN

SELECT kosten FROM av_geschaeftskontrolle.auftrag WHERE id = NEW.auftrag_id INTO gesamtkosten;
NEW.kosten = gesamtkosten*(NEW.prozent/100);
 
 RETURN NEW;
 END;$function$
;



