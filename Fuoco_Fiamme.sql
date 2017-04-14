/*Ripulisce, eliminando le tabelle qualora esistessero gia'*/

SET FOREIGN_KEY_CHECKS=0;
DROP VIEW IF EXISTS VISTA1;
DROP VIEW IF EXISTS A;
DROP VIEW IF EXISTS B;
DROP VIEW IF EXISTS N_o_eff;

DROP PROCEDURE IF EXISTS AssegnaTavoli;
DROP PROCEDURE IF EXISTS Elimina_PRE;
DROP FUNCTION IF EXISTS Introito;
DROP FUNCTION IF EXISTS NumOrdine;
DROP TRIGGER IF EXISTS Disposizione;
DROP TRIGGER IF EXISTS Ordinazione;
DROP TRIGGER IF EXISTS EliminaOccupazione;

DROP TABLE IF EXISTS Personale;
DROP TABLE IF EXISTS Prenotazioni;
DROP TABLE IF EXISTS Categorie;
DROP TABLE IF EXISTS Sale;
DROP TABLE IF EXISTS Tavoli;
DROP TABLE IF EXISTS Fornitori;
DROP TABLE IF EXISTS Ordini;
DROP TABLE IF EXISTS Articoli;
DROP TABLE IF EXISTS Composizione;
DROP TABLE IF EXISTS Ricevute;
DROP TABLE IF EXISTS Occupazioni;



/*Crea la tabella Categoria*/

CREATE TABLE Categorie(
 Nome VARCHAR (20) PRIMARY KEY,
 Stipendio_Base DOUBLE NOT NULL
) ENGINE=InnoDB;


/*Crea la tabella degli Personale*/

CREATE TABLE Personale(
 CF VARCHAR(16) PRIMARY KEY,
 Nome VARCHAR(20) NOT NULL,	
 Cognome VARCHAR(20) NOT NULL,
 Sesso ENUM('M','F') NOT NULL,
 Data_Nascita DATE NOT NULL,
 Data_Assunzione DATE NOT NULL,
 Termine_Contratto DATE DEFAULT NULL,	
 Categoria VARCHAR(20),
 FOREIGN KEY (Categoria) REFERENCES Categorie (Nome)
 ON DELETE SET NULL
 ON UPDATE CASCADE
)ENGINE=InnoDB;


/*Crea la tabella Sale*/

CREATE TABLE Sale(
 Codice VARCHAR(1) PRIMARY KEY,
 Descrizione VARCHAR(250),
 Responsabile VARCHAR(16),
 FOREIGN KEY (Responsabile) REFERENCES Personale (CF)
 ON DELETE SET NULL
)ENGINE=InnoDB;


/*Crea la tabella Tavoli*/

CREATE TABLE Tavoli(
 Numero SMALLINT,
 Sala VARCHAR(1),
 Posti TINYINT NOT NULL,
 PRIMARY KEY(Numero,Sala),
 FOREIGN KEY (Sala) REFERENCES Sale (Codice)
 ON DELETE CASCADE
 ON UPDATE CASCADE
)ENGINE=InnoDB;


/*Crea la tabella Penotazione*/

CREATE TABLE Prenotazioni(
 ID INT PRIMARY KEY AUTO_INCREMENT,
 Data DATE NOT NULL,
 Ora TIME NOT NULL,     
 N_Posti SMALLINT NOT NULL,
 Cognome VARCHAR(20) NOT NULL
) ENGINE=InnoDB;


/*Crea la tabella Occupazioni*/

CREATE TABLE Occupazioni(
 Tavolo SMALLINT,
 Sala VARCHAR(1),
 Prenotazione INT,
 PRIMARY KEY(Tavolo,Sala,Prenotazione),
 FOREIGN KEY (Prenotazione) REFERENCES Prenotazioni (ID)
 ON DELETE CASCADE,
 FOREIGN KEY (Tavolo,Sala)  REFERENCES Tavoli (Numero,Sala)
)ENGINE=InnoDB;

/*Crea la tabella Ricevute*/

CREATE TABLE Ricevute(
 Codice INT PRIMARY KEY AUTO_INCREMENT,
 Tipo_Pagamento  ENUM('Carta di Credito','Contanti','Prepagata') NOT NULL,
 Ora TIME NOT NULL,
 Data DATE NOT NULL,
 Totale DOUBLE NOT NULL,
 Tavolo SMALLINT ,       
 Sala VARCHAR(1) ,
 FOREIGN KEY (Tavolo,Sala) REFERENCES Tavoli (Numero,Sala)
 ON DELETE SET NULL
) ENGINE=InnoDB;


/*Crea tabella Fornitori*/

CREATE TABLE Fornitori(
 P_IVA VARCHAR(20) PRIMARY KEY,
 Nome VARCHAR(50) NOT NULL,
 Indirizzo VARCHAR(250) NOT NULL,
 Telefono VARCHAR(15),
 Email VARCHAR(50)
)ENGINE=InnoDB;

/*Crea tabella Articoli*/

CREATE TABLE Articoli(
 ID INT PRIMARY KEY AUTO_INCREMENT,
 Nome VARCHAR(25) NOT NULL,
 Descrizione VARCHAR(250),
 Quantita INT NOT NULL
)ENGINE=INNODB;

/*Crea tabella Ordini*/

CREATE TABLE Ordini(
 N_Ordine INT PRIMARY KEY AUTO_INCREMENT,
 Data DATE NOT NULL,
 Stato ENUM('In Corso','Completato','Annullato') DEFAULT 'In Corso',
 Committente VARCHAR(16),
 Fornitore VARCHAR(20),
 FOREIGN KEY (Committente) REFERENCES Personale (CF),
 FOREIGN KEY (Fornitore) REFERENCES Fornitori (P_IVA)
)ENGINE=INNODB;


/*Crea tabella Composizione*/

CREATE TABLE Composizione(
 Ordine INT,
 Articolo INT,
 Quantita INT NOT NULL,
 PRIMARY KEY(Ordine, Articolo),
 FOREIGN KEY (Ordine) REFERENCES Ordini(N_Ordine),
 FOREIGN KEY (Articolo) REFERENCES Articoli(ID)
)ENGINE=INNODB;

/*Crea VISTA1*/

CREATE VIEW VISTA1(Nome_Fornitore, Nome_Articolo, Quantita) AS
SELECT f.Nome, a.Nome, SUM(c.Quantita)
FROM Ordini o JOIN Fornitori f ON (o.Fornitore=f.P_IVA)
                JOIN Composizione c ON (o.N_Ordine=c.Ordine)
                    JOIN Articoli a ON (c.Articolo=a.ID)
GROUP BY o.Fornitore, a.Nome;

/*Crea VIEW A*/

CREATE VIEW A(Descrizione, N_Tavoli_Occupati, N_Posti_Occupati) AS
SELECT S.Descrizione, COUNT(O.Tavolo) AS N_Tavoli_Occupati, SUM(P.N_Posti) AS N_Posti_Occupati
FROM Occupazioni O,Prenotazioni P,Sale S
WHERE O.Prenotazione=P.ID AND P.Data='2017/02/18' AND P.Ora>20 AND S.Codice=O.Sala
GROUP BY S.Descrizione;

/*Crea VIEW B*/

CREATE VIEW B(Descrizione, N_Tavoli_Liberi, N_Posti_Liberi) AS
SELECT S.Descrizione, COUNT(T.Numero), SUM(T.Posti)
FROM Tavoli T, Sale S
WHERE S.Codice=T.Sala
GROUP BY S.Descrizione;

/*Crea VIEW NUmero Ordini Effettuati*/

CREATE VIEW N_o_eff(CF,N_Ordini) AS
SELECT O.Committente,count(*)
FROM Ordini O
GROUP BY O.Committente;

/*Crea Procedure*/

/*Crea Procedura AssegnaTavoli-
Se la prenotazione è di un numero che non supera il tavolo più grande a disposizione, 
assegna un tavolo idoneo alla prenotazione.*/
DELIMITER //
CREATE PROCEDURE AssegnaTavoli(NPosti SMALLINT,Data DATE ,ID INT)
BEGIN
	DECLARE nmax SMALLINT;
	DECLARE ntav SMALLINT;
	DECLARE nsal VARCHAR(1);

	SELECT MAX(Tavoli.Posti)
	FROM Tavoli 
	WHERE Tavoli.Numero NOT IN(
	SELECT Tavolo FROM Occupazioni, Prenotazioni
	WHERE Occupazioni.Prenotazione=Prenotazioni.ID AND Prenotazioni.Data=Data) INTO nmax;

	IF NPosti <= nmax THEN 
	SELECT Tavoli.Numero 
	FROM Tavoli
	WHERE Tavoli.Posti>=NPosti AND Tavoli.Numero NOT IN(

	SELECT Occupazioni.Tavolo 
	from Occupazioni , Prenotazioni,Tavoli  
	WHERE Prenotazioni.Data=Data
	) 
	LIMIT 1 INTO ntav;

	select Tavoli.Sala from Tavoli  where Tavoli.Numero=ntav AND Tavoli.Posti>=NPosti limit 1 INTO nsal;

	INSERT INTO Occupazioni (Tavolo,Sala,Prenotazione) VALUES (ntav,nsal,ID);
	END IF;
END //
DELIMITER ;


/*Crea Procedure Elimina Prenotazioni terminata una prenotazione, la elimina.*/
DELIMITER //
CREATE PROCEDURE Elimina_PRE(PR INT)
BEGIN
DELETE FROM Prenotazioni 
WHERE Prenotazioni.ID=PR;
END //
DELIMITER ;

/*Crea Funzioni*/ 

/*Crea funzione Introito*/

DELIMITER //
CREATE FUNCTION Introito (ANNO INT) 
RETURNS DOUBLE
BEGIN
DECLARE N DOUBLE;
Select SUM(Totale)  from Ricevute R WHERE ANNO=YEAR(R.Data) INTO N;
return N;
END //
DELIMITER ;


/*Crea Function Numero Ordine*/

DELIMITER //
CREATE FUNCTION NumOrdine(X INT) 
RETURNS INT

BEGIN
DECLARE N INT;
SELECT count(*)
FROM Composizione
WHERE Articolo=X INTO N;
return N;
END //
DELIMITER ;

/*Crea Triger */

/*Crea Trigger Disposizione*/

DELIMITER //
CREATE trigger Disposizione AFTER INSERT ON Prenotazioni
FOR EACH ROW
BEGIN
 call AssegnaTavoli(new.N_Posti,new.Data,new.ID);
END //
DELIMITER ;

/*Crea Trigger Ordinazione -
Solo uno chef o un direttore possono effettuare ordini.*/

DELIMITER //
CREATE trigger Ordinazione BEFORE INSERT ON Ordini
FOR EACH ROW
BEGIN
IF new.Committente NOT IN (SELECT CF FROM Personale where Categoria='Direttore' OR Categoria='Chef') THEN
DELETE FROM Ordini WHERE Ordini.Committente=new.Committente;
END IF;
END //
DELIMITER ;

/*Elimina Occupazione*/
/*Elimina occupazioni e prenotazioni Che hanno Saldato il conto*/

DELIMITER //
create trigger EliminaOccupazione after insert on Ricevute
for each row
BEGIN
DECLARE PR INT;

select Occupazioni.Prenotazione
from Occupazioni
where Occupazioni.Tavolo=new.Tavolo AND
Occupazioni.Sala=new.Sala INTO PR;
call Elimina_PRE(PR);
END //
DELIMITER ;


LOAD DATA LOCAL INFILE 'Prenotazioni.txt' INTO TABLE Prenotazioni;
LOAD DATA LOCAL INFILE 'Categorie.txt' INTO TABLE Categorie;
LOAD DATA LOCAL INFILE 'Personale.txt' INTO TABLE Personale;
LOAD DATA LOCAL INFILE 'Sale.txt' INTO TABLE Sale;
LOAD DATA LOCAL INFILE 'Tavoli.txt' INTO TABLE Tavoli;
LOAD DATA LOCAL INFILE 'Ricevute.txt' INTO TABLE Ricevute;
LOAD DATA LOCAL INFILE 'Fornitori.txt' INTO TABLE Fornitori;
LOAD DATA LOCAL INFILE 'Articoli.txt' INTO TABLE Articoli;
LOAD DATA LOCAL INFILE 'Ordini.txt' INTO TABLE Ordini;
LOAD DATA LOCAL INFILE 'Composizione.txt' INTO TABLE Composizione;
LOAD DATA LOCAL INFILE 'Occupazioni.txt' INTO TABLE Occupazioni;

SET FOREIGN_KEY_CHECKS=1;