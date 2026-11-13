# Preporuke salona u RezervisiMe

Sistem rangira verifikovane salone za korisnika iz JWT-a. Interes za kategoriju računa se iz broja zabilježenih filtriranja usluga po kategoriji i kategorija ranijih rezervacija. Tekstualni pojam se bilježi uz pretragu. Bodovanje koristi zapise koji imaju kategoriju.

Udio korisnikovih interesa koje salon pokriva nosi 60% konačne ocjene. Popularnost nosi 40%. Popularnost se računa iz prosječne ocjene podijeljene s pet (70% komponente) i broja recenzija podijeljenog najvećim brojem recenzija među kandidatima (30%). Saloni kod kojih korisnik još nije rezervisao dobijaju 0,05 dodatnih bodova. Bez historije interesa sadržajna komponenta je nula, pa redoslijed određuju popularnost i bonus.

API uz rezultat vraća objašnjenje na osnovu poklapanja kategorija, ocjene i prethodnih rezervacija. Za integracijsku provjeru uporediti rezultate novog korisnika i istog korisnika nakon filtriranja usluga po kategoriji. Provjeriti i salone s različitim brojem recenzija i prosječnim ocjenama.
