# these commands update the existing etyma and notes table to
# prefix the existing chapters with a "1.".
# note that other "non-bp" chapters will need to be fixed by hand as well at some point.
#
# note: these commands are included for posterity: they should be only run once!
use stedt;
update etyma set chapter = concat("1.",chapter) where chapter < "99." and chapter != "";
update notes set id = concat("1.",id) where id <= "9." and id != "" and rn = 0 ;
#select tag,protogloss,chapter from etyma where chapter < "99" and chapter != "";
