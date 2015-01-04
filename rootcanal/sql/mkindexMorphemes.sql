  delete from morphemes where reflex = "reflex";
  delete from morphemes where length(morpheme) > 16;

  CREATE INDEX idx_morphemes_rn ON morphemes (rn);
  CREATE INDEX idx_morphemes_lgid ON morphemes (lgid);
  CREATE INDEX idx_morphemes_mseq ON morphemes (mseq);
  CREATE INDEX idx_morphemes_handle ON morphemes (handle);

  CREATE INDEX idx_morphemes_prefx ON morphemes (prefx);
  CREATE INDEX idx_morphemes_initial ON morphemes (initial);
  CREATE INDEX idx_morphemes_rhyme ON morphemes (rhyme);
  CREATE INDEX idx_morphemes_tone ON morphemes (tone);

  CREATE INDEX idx_morphemes_grp ON morphemes (grp);
  CREATE INDEX idx_morphemes_grpno ON morphemes (grpno);
  CREATE INDEX idx_morphemes_language ON morphemes (language);
  CREATE INDEX idx_morphemes_semkey ON morphemes (semkey);
  CREATE INDEX idx_morphemes_reflex ON morphemes (reflex);
  CREATE INDEX idx_morphemes_gloss ON morphemes (gloss);
  CREATE INDEX idx_morphemes_gfn ON morphemes (gfn);
 
  update morphemes set glosshandle = trim(left(glosshandle,instr(glosshandle,'/')-1)) where instr(trim(glosshandle),'/') > 0;
  update morphemes set glosshandle = trim(left(glosshandle,instr(glosshandle,',')-1)) where instr(trim(glosshandle),',') > 0;
  update morphemes set glosshandle = trim(left(glosshandle,instr(glosshandle,';')-1)) where instr(trim(glosshandle),';') > 0;
  update morphemes set glosshandle = trim(left(glosshandle,instr(glosshandle,'(')-1)) where instr(trim(glosshandle),'(') > 0;  
  update morphemes set glosshandle = trim(left(glosshandle,length(glosshandle)-1)) where substr(glosshandle,length(glosshandle)) = "s" and instr('aeious',substr(glosshandle,length(glosshandle)-1,1)) = 0 ;

  update morphemes set glosshandle = upper(glosshandle);

  update morphemes set morpheme = replace(morpheme,'[','');
  update morphemes set morpheme = replace(morpheme,']','');
  update morphemes set morpheme = replace(morpheme,'(','');
  update morphemes set morpheme = replace(morpheme,')','');
  update morphemes set morpheme = replace(morpheme,'*','');

  CREATE INDEX idx_morphemes_morpheme ON morphemes (morpheme);

  CREATE INDEX idx_morphemes_glosshandle ON morphemes (glosshandle);
  update morphemes m,lx_et_hash x set m.tag = x.tag where m.rn=x.rn and m.mseq = x.ind;
  CREATE index idx_morphemes_tag on stedt.morphemes (tag);
