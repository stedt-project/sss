DROP TABLE IF EXISTS soundlawsupport;
CREATE TABLE soundlawsupport 
SELECT 
x.rn AS rn,
x.rn AS slid,
x.tag AS tag,
m.mseq AS mseq,
x.ind AS ind,
'I' AS slot,
g.plg AS protolg,
e.initial AS ancestor,
m.initial AS outcome,
m.language AS language,
m.lgid AS lgid,
m.srcabbr AS srcabbr,
m.srcid AS srcid,
e.protoform AS protoform,
e.protogloss AS protogloss,
m.reflex AS reflex,
m.gloss AS gloss,
m.morpheme AS morpheme
FROM lx_et_hash x 
JOIN morphemes m on (x.rn=m.rn and m.mseq=x.ind) 
JOIN etyma e on (e.tag = x.tag)
JOIN languagegroups g on (g.grpno = m.grpno)
;

INSERT INTO soundlawsupport 
SELECT 
x.rn AS rn,
x.rn AS slid,
x.tag AS tag,
x.ind AS ind,
m.mseq AS mseq,
'R' AS slot,
g.plg AS protolg,
e.rhyme AS ancestor,
m.rhyme AS outcome,
m.language AS language,
m.lgid AS lgid,
m.srcabbr AS srcabbr,
m.srcid AS srcid,
e.protoform AS protoform,
e.protogloss AS protogloss,
m.reflex AS reflex,
m.gloss AS gloss,
m.morpheme AS morpheme
FROM lx_et_hash x
JOIN morphemes m on (x.rn=m.rn and m.mseq=x.ind)
JOIN etyma e on (e.tag = x.tag)
JOIN languagegroups g on (g.grpno = m.grpno)
;

ALTER TABLE soundlawsupport ADD id INT NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (id);

update soundlawsupport set ancestor = left(ancestor,instr(ancestor,'⪤')-1) WHERE instr(ancestor,'⪤') > 0;
update soundlawsupport set ancestor = left(ancestor,instr(ancestor,' ')-1) WHERE instr(ancestor,' ') > 0;
update soundlawsupport set ancestor = left(ancestor,instr(ancestor,'=')-1) WHERE instr(ancestor,'=') > 0;
update soundlawsupport set ancestor = left(ancestor,instr(ancestor,'~')-1) WHERE instr(ancestor,'~') > 0;
update soundlawsupport set outcome = ltrim(outcome), ancestor=ltrim(ancestor);
update soundlawsupport set outcome = rtrim(outcome), ancestor=rtrim(ancestor);

DROP TABLE IF EXISTS soundlaws;
CREATE TABLE soundlaws SELECT slid,slot,protolg,ancestor,outcome,language,'' AS context,count(*) AS n FROM soundlawsupport group by slot,ancestor,outcome,language ORDER BY n;
ALTER TABLE soundlaws ADD id INT NOT NULL AUTO_INCREMENT FIRST, ADD PRIMARY KEY (id);
DELETE FROM soundlaws WHERE n < 2;
DELETE FROM soundlaws WHERE outcome = '' OR ancestor = '';

CREATE INDEX idx_soundlaws_id ON soundlaws (id);
CREATE INDEX idx_soundlaws_slot ON soundlaws (slot);
CREATE INDEX idx_soundlaws_protolg ON soundlaws (protolg);
CREATE INDEX idx_soundlaws_ancestor ON soundlaws (ancestor);
CREATE INDEX idx_soundlaws_outcome ON soundlaws (outcome);
CREATE INDEX idx_soundlaws_language ON soundlaws (language);
CREATE INDEX idx_soundlaws_n ON soundlaws (n);

CREATE INDEX idx_soundlawsupport_id ON soundlawsupport (id);
CREATE INDEX idx_soundlawsupport_slid ON soundlawsupport (slid);
CREATE INDEX idx_soundlawsupport_tag ON soundlawsupport (tag);
CREATE INDEX idx_soundlawsupport_slot ON soundlawsupport (slot);
CREATE INDEX idx_soundlawsupport_protolg ON soundlawsupport (protolg);
CREATE INDEX idx_soundlawsupport_ancestor ON soundlawsupport (ancestor);
CREATE INDEX idx_soundlawsupport_outcome ON soundlawsupport (outcome);
CREATE INDEX idx_soundlawsupport_language ON soundlawsupport (language);
CREATE INDEX idx_soundlawsupport_srcabbr ON soundlawsupport (srcabbr);
CREATE INDEX idx_soundlawsupport_srcid ON soundlawsupport (srcid);
CREATE INDEX idx_soundlawsupport_lgid ON soundlawsupport (lgid);

UPDATE soundlawsupport l SET slid = (SELECT s.id FROM soundlaws s WHERE s.slot=l.slot AND s.ancestor=l.ancestor AND s.outcome=l.outcome AND s.language=l.language);

