SET foreign_key_checks = 0;

-- TABELLE --

DROP TABLE IF EXISTS user;
DROP TABLE IF EXISTS media;
DROP TABLE IF EXISTS event;
DROP TABLE IF EXISTS category;
DROP TABLE IF EXISTS team;
DROP TABLE IF EXISTS follow_user;
DROP TABLE IF EXISTS follow_category;
DROP TABLE IF EXISTS friend;
DROP TABLE IF EXISTS subscribe;
DROP TABLE IF EXISTS tag;
DROP TABLE IF EXISTS attach_media;
DROP TABLE IF EXISTS attach_category;
DROP TABLE IF EXISTS message;
DROP TABLE IF EXISTS clip;

CREATE TABLE user
  (
     id              INT auto_increment PRIMARY KEY,
     username        VARCHAR(128) NOT NULL UNIQUE,
     email           VARCHAR(128) NOT NULL UNIQUE,
     password        VARCHAR(254) NOT NULL,
     biography       TINYTEXT,
     profile_picture BLOB,
     status          ENUM('online', 'offline', 'invisible') NOT NULL DEFAULT 'offline',
     views           INT NOT NULL DEFAULT 0,
     followers       INT NOT NULL DEFAULT 0,
     streaming_id    INT,
     watching_id     INT,
     team_id         INT,
     FOREIGN KEY(streaming_id) REFERENCES media(id) ON DELETE SET NULL,
     FOREIGN KEY(watching_id) REFERENCES media(id) ON DELETE SET NULL,
     FOREIGN KEY(team_id) REFERENCES team(id) ON DELETE SET NULL
  )
engine=innodb;

CREATE TABLE media
  (
     id            INT auto_increment PRIMARY KEY,
     file_id       VARCHAR(255) NOT NULL,
     title         VARCHAR(255) NOT NULL,
     begin         DATETIME NOT NULL,
     end           DATETIME,
     published     BOOL NOT NULL DEFAULT FALSE,
     views         INT NOT NULL DEFAULT 0,
     viewers       INT NOT NULL DEFAULT 0,
     chat_mode     ENUM('follow_only', 'sub_only'),
     chat_mode_age INT,
     streamer_id   INT NOT NULL,
	 category_id   INT NOT NULL,
     FOREIGN KEY(streamer_id) REFERENCES user(id) ON DELETE CASCADE,
	 FOREIGN KEY(category_id) REFERENCES category(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE event
  (
     id          INT auto_increment PRIMARY KEY,
     name        VARCHAR(128) NOT NULL UNIQUE,
     description TINYTEXT,
     begin       DATETIME NOT NULL,
     end         DATETIME NOT NULL,
     streamer_id INT NOT NULL,
     category_id INT NOT NULL,
     FOREIGN KEY(streamer_id) REFERENCES user(id) ON DELETE CASCADE,
     FOREIGN KEY(category_id) REFERENCES category(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE category
  (
     id        INT auto_increment PRIMARY KEY,
     name      VARCHAR(128) NOT NULL UNIQUE
  )
engine=innodb;

CREATE TABLE team
  (
     id          INT auto_increment PRIMARY KEY,
     name        VARCHAR(128) NOT NULL UNIQUE,
     description TINYTEXT
  )
engine=innodb;

CREATE TABLE follow_user
  (
     follower_id INT NOT NULL,
     streamer_id INT NOT NULL,
     begin       DATETIME NOT NULL,
     PRIMARY KEY(follower_id, streamer_id),
     FOREIGN KEY(follower_id) REFERENCES user(id) ON DELETE CASCADE,
     FOREIGN KEY(streamer_id) REFERENCES user(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE follow_category
  (
     follower_id INT NOT NULL,
     category_id INT NOT NULL,
     PRIMARY KEY(follower_id, category_id),
     FOREIGN KEY(follower_id) REFERENCES user(id) ON DELETE CASCADE,
     FOREIGN KEY(category_id) REFERENCES category(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE friend
  (
     sender_id   INT NOT NULL,
     receiver_id INT NOT NULL,
     accepted    BOOL NOT NULL DEFAULT FALSE,
     PRIMARY KEY(receiver_id, sender_id),
     FOREIGN KEY(sender_id) REFERENCES user(id) ON DELETE CASCADE,
     FOREIGN KEY(receiver_id) REFERENCES user(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE subscribe
  (
     follower_id INT NOT NULL,
     streamer_id INT NOT NULL,
     begin       DATETIME NOT NULL,
     tier        ENUM('1', '2', '3') NOT NULL,
     PRIMARY KEY(follower_id, streamer_id),
     FOREIGN KEY(follower_id) REFERENCES user(id) ON DELETE CASCADE,
     FOREIGN KEY(streamer_id) REFERENCES user(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE tag
  (
     name VARCHAR(128) PRIMARY KEY
  )
engine=innodb;

CREATE TABLE attach_media
  (
     tag_name VARCHAR(128) NOT NULL,
     media_id INT NOT NULL,
     PRIMARY KEY(tag_name, media_id),
     FOREIGN KEY(tag_name) REFERENCES tag(name) ON DELETE CASCADE,
     FOREIGN KEY(media_id) REFERENCES media(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE attach_category
  (
     tag_name    VARCHAR(128) NOT NULL,
     category_id INT NOT NULL,
     PRIMARY KEY(tag_name, category_id),
     FOREIGN KEY(tag_name) REFERENCES tag(name) ON DELETE CASCADE,
     FOREIGN KEY(category_id) REFERENCES category(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE message
  (
     id        INT auto_increment PRIMARY KEY,
     text      TINYTEXT NOT NULL,
     sent_at   DATETIME NOT NULL DEFAULT NOW(),
     sender_id INT NOT NULL,
     media_id  INT NOT NULL,
     FOREIGN KEY(sender_id) REFERENCES user(id) ON DELETE CASCADE,
     FOREIGN KEY(media_id) REFERENCES media(id) ON DELETE CASCADE
  )
engine=innodb;

CREATE TABLE clip
  (
     id         INT auto_increment PRIMARY KEY,
     begin      DATETIME NOT NULL,
     end        DATETIME NOT NULL,
     views      INT NOT NULL DEFAULT 0,
     create_at  DATETIME NOT NULL,
     creator_id INT NOT NULL,
     media_id   INT NOT NULL,
     FOREIGN KEY(creator_id) REFERENCES user(id) ON DELETE CASCADE,
     FOREIGN KEY(media_id) REFERENCES media(id) ON DELETE CASCADE
  )
engine=innodb;

-- QUERY e PROCEDURE --

-- Operazione 2: concludere una live ed eventualmente pubblicarla come video 
DROP PROCEDURE IF EXISTS end_live;
DELIMITER |
CREATE PROCEDURE end_live(IN media_id INT, IN publish BOOL) 
BEGIN
    UPDATE media SET end = NOW(), published = publish
    WHERE id = media_id;
	
	UPDATE user SET watching_id = NULL
	WHERE watching_id = media_id;
END |
DELIMITER ;

-- Operazione 15: visualizzare il numero totale di spettatori di tutte livestream per una data categoria
DROP PROCEDURE IF EXISTS category_viewers;
DELIMITER |
CREATE PROCEDURE category_viewers(IN category_id INT) 
BEGIN
    SELECT c.id, c.name, SUM(m.viewers) AS views
    FROM category c INNER JOIN media m ON m.category_id = c.id WHERE c.id = category_id
    GROUP BY c.id;
END |
DELIMITER ;

-- Operazione 18:  visualizzare le live che stanno guardando gli amici di un utente
DROP PROCEDURE IF EXISTS search_friends_watching;
DELIMITER |
CREATE PROCEDURE search_friends_watching(IN user_id INT)
BEGIN
	SELECT u.username AS friend_username, s.username AS watching_username, l.id AS live_id, c.id AS category_id, c.name AS category_name FROM user u
	INNER JOIN
		(SELECT f.receiver_id AS friend_id
		FROM friend f
		WHERE f.sender_id = user_id AND accepted = TRUE
		UNION
		SELECT f.sender_id AS friend_id
		FROM friend f
		WHERE f.receiver_id = user_id AND accepted = TRUE) f ON u.id = f.friend_id
	INNER JOIN media l ON u.watching_id = l.id
	INNER JOIN user s ON s.id = l.streamer_id
	INNER JOIN category c ON l.category_id = c.id
	WHERE u.status = 'online';
END |
DELIMITER ;

-- Operazione 19: ricercare livestream o video pubblicati che contengono un certo tag o una certa parola nel titolo
DROP PROCEDURE IF EXISTS search_media;
DELIMITER |
CREATE PROCEDURE search_media(IN word VARCHAR(128)) 
BEGIN
	SELECT m.id, m.title
	FROM media m
	WHERE (m.end IS NULL OR m.published = TRUE) AND (m.title LIKE CONCAT('%', word, '%') OR word IN (SELECT a.tag_name FROM attach_media a WHERE a.media_id = m.id));
END |
DELIMITER ;

-- Operazione 21: visualizzare le top 10 livestream con il maggior numero di spettatori, relative agli streamer seguiti dall'utente
DROP PROCEDURE IF EXISTS search_top_followed_live;
DELIMITER |
CREATE PROCEDURE search_top_followed_live(IN user_id INT)
BEGIN
	SELECT u.username AS streamer_username, l.id, l.title, l.viewers FROM media l
	INNER JOIN follow_user f ON (f.follower_id = user_id AND f.streamer_id = l.streamer_id)
	INNER JOIN user u ON u.id = l.streamer_id
	WHERE l.end IS NULL
	ORDER BY l.viewers DESC LIMIT 10;
END |
DELIMITER ;

-- Operazione 22: visualizzare le live con il maggior numero di spettatori per ogni categoria
DROP VIEW IF EXISTS search_top_live_by_category;
CREATE VIEW search_top_live_by_category AS
	SELECT m.title, c.name AS category_name
	FROM media m INNER JOIN category c ON c.id = m.category_id
	WHERE m.end IS NULL AND m.id = (SELECT e.id FROM media e WHERE e.category_id = m.category_id ORDER by viewers DESC LIMIT 1);

-- FUNZIONI --

-- Operazione 4: mandare, se permesso, un messaggio nella chat di una livestream
DROP FUNCTION IF EXISTS post_message;
DELIMITER |
CREATE FUNCTION post_message(user_id INT, live_id INT, text VARCHAR(128)) RETURNS BOOL
BEGIN
    DECLARE media_end DATETIME;
    DECLARE active_chat_mode VARCHAR(20);
    DECLARE active_chat_mode_age INT;
    DECLARE allowed BOOL;
    DECLARE since DATETIME;
    DECLARE current_streamer_id INT;
    SET since = NULL;
    SET allowed = TRUE;
    SELECT m.streamer_id INTO current_streamer_id FROM media m WHERE m.id = live_id;
    SELECT m.end INTO media_end FROM media m WHERE m.id = live_id;
    IF (media_end IS NULL AND current_streamer_id IS NOT NULL) THEN
        SELECT m.chat_mode, m.chat_mode_age INTO active_chat_mode, active_chat_mode_age FROM media m WHERE m.id =  live_id;
        IF(active_chat_mode IS NOT NULL) THEN
            IF (active_chat_mode = 'follow_only') THEN
                SELECT f.begin INTO since FROM follow_user f WHERE f.follower_id = user_id AND f.streamer_id = current_streamer_id;
            ELSE
                SELECT s.begin INTO since FROM subscribe s WHERE s.subscriber_id = user_id AND s.streamer_id = current_streamer_id;
         	END IF;
			IF (since IS NOT NULL) THEN
                IF (active_chat_mode_age IS NOT NULL AND UNIX_TIMESTAMP(NOW()) - UNIX_TIMESTAMP(since) < active_chat_mode_age) THEN
                	SET allowed = FALSE;
				END IF;
			ELSE
				SET allowed = FALSE;
            END IF; 
        END IF;
    ELSE
        SET allowed = FALSE;
    END IF;
	IF (allowed) THEN
		INSERT INTO message(text, sender_id, media_id) VALUES(text, user_id, live_id);
	END IF;
    RETURN allowed;
END | 
DELIMITER ;

-- Operazione 11: mandare richieste di amicizia ad altri utenti
DROP FUNCTION IF EXISTS send_friend_request;
DELIMITER |
CREATE FUNCTION send_friend_request(s_id INT, r_id INT) RETURNS BOOL
BEGIN
	DECLARE already_exists INT;
	SELECT sender_id INTO already_exists FROM friend f WHERE (f.sender_id = s_id AND f.receiver_id = r_id) 
		OR (f.sender_id = r_id AND f.receiver_id = s_id);

	IF(already_exists IS NOT NULL) THEN
		return FALSE;
	ELSE
		INSERT INTO friend(sender_id, receiver_id) VALUES(s_id, r_id);
		return TRUE;
	END IF;
END | 
DELIMITER ;

-- TRIGGERS --

-- Regola di vincolo: il contatore viewers di una livestream deve essere aggiornato quando un utente inizia o finisce di guardarla
DROP TRIGGER IF EXISTS update_watching_counter;
DELIMITER |
CREATE TRIGGER update_watching_counter
AFTER UPDATE ON user
FOR EACH ROW
BEGIN
DECLARE old_counter INT;
    IF (NEW.watching_id <> OLD.watching_id OR NEW.watching_id IS NULL OR OLD.watching_id IS NULL) THEN
        IF(OLD.watching_id IS NOT NULL) THEN
            SELECT m.viewers INTO old_counter
            FROM media m
            WHERE m.id = OLD.watching_id;
            UPDATE media SET viewers = old_counter - 1
            WHERE id = old.watching_id;
        END IF;
        IF (NEW.watching_id IS NOT NULL) THEN
            SELECT m.viewers INTO old_counter
            FROM media m
            WHERE m.id = new.watching_id;
            UPDATE media SET viewers = old_counter + 1
            WHERE id = new.watching_id;
        END IF;
    END IF;
END | 
DELIMITER ;

-- Regola di vincolo: il contatore followers di un utente deve essere aggiornato quando quest'ultimo acquisisce o perde un seguace
DROP TRIGGER IF EXISTS increase_followers_counter;
DELIMITER |
CREATE TRIGGER increase_followers_counter
AFTER INSERT ON follow_user
FOR EACH ROW
BEGIN
DECLARE old_counter INT;
	SELECT followers INTO old_counter
    FROM user u WHERE u.id = NEW.streamer_id;
    UPDATE user SET followers = old_counter + 1
    WHERE id = NEW.streamer_id;
END | 
DELIMITER ;

-- Regola di vincolo: il contatore followers di un utente deve essere aggiornato quando quest'ultimo acquisisce o perde un seguace
DROP TRIGGER IF EXISTS decrease_followers_counter;
DELIMITER |
CREATE TRIGGER decrease_followers_counter
AFTER DELETE ON follow_user
FOR EACH ROW
BEGIN
DECLARE old_counter INT;
	SELECT followers INTO old_counter
    FROM user u WHERE u.id = OLD.streamer_id;
    UPDATE user SET followers = old_counter - 1
    WHERE id = OLD.streamer_id;
END | 
DELIMITER ;

-- POPOLAMENTO DB

INSERT INTO `user` (`id`, `username`, `email`, `password`, `biography`, `profile_picture`, `status`, `views`, `followers`, `streaming_id`, `watching_id`, `team_id`) VALUES
(1, 'gamesoup', 'andrea.rossi@email.com', '5baa61e4c9b93f3f0682250b6cf8331b7ee68fd8', 'I live in Spain', NULL, 'online', 6, 6, 1, NULL, 1),
(2, 'happymark', 'mark.agg@gmail.com', '2aa60a8ff7fcd473d321e0146afd9e26df395147', NULL, NULL, 'online', 2, 2, 3, NULL, 1),
(3, 'gtree', 'giac.duck@yahoo.com', 'f9fd3350fe485249147aa3f763e4a9f879d1cd48', 'Have fun', NULL, 'online', 0, 0, NULL, 3, NULL),
(4, 'grimel', 'g.ale@hotmail.com', 'ee7ac7d62bfff7dfbccea5dad5c12f0ebf00892f', NULL, NULL, 'online', 0, 0, NULL, 1, NULL),
(5, 'aleale', 'ale.ndro@yey.com', '6329557f247ae36b38a04472e9c18f75437b7a08', NULL, NULL, 'online', 0, 2, NULL, 3, NULL),
(6, 'gjoe', 'g.joe@gmail.com', '512c73fa1bcc947eae82a4654575df076c3b008d', NULL, NULL, 'online', 0, 0, NULL, 1, NULL),
(7, 'mlime', 'm.lime@gmail.com', '31456efde0d524f23dce9b488705eb90fc597924', NULL, NULL, 'online', 0, 1, 4, NULL, NULL),
(8, 'orange', 'gorange@gmail.com', '454240d524f23dce9b488705eb90fc597924', NULL, NULL, 'online', 0, 0, NULL, 4, NULL);

INSERT INTO `media` (`id`, `file_id`, `title`, `begin`, `end`, `published`, `views`, `viewers`, `chat_mode`, `chat_mode_age`, `streamer_id`, `category_id`) VALUES
(1, '24091e72-cd6b-11e9-a32f-2a2ae2dbcce4', 'My new game', '2019-09-01 06:00:00', NULL, 0, 0, 2, 'follow_only', NULL, 1, 6),
(2, '3f2516f2-cd6b-11e9-a32f-2a2ae2dbcce4', 'WORST GAME EVER', '2019-08-28 06:00:00', '2019-08-28 08:00:00', 1, 4, 0, 'sub_only', NULL, 1, 4),
(3, 'ced9a858-cd6b-11e9-a32f-2a2ae2dbcce4', 'EPIC', '2019-09-02 02:00:00', NULL, 0, 0, 2, 'follow_only', 180, 2, 6),
(4, '27a40088-cd7f-11e9-a32f-2a2ae2dbcce4', 'MY BORING PODCAST', '2019-09-01 00:00:00', NULL, 0, 0, 1, NULL, NULL, 7, 8);


INSERT INTO `team` (`id`, `name`, `description`) VALUES
(1, 'WeWinners', NULL);

INSERT INTO `category` (`id`, `name`) VALUES
(10, 'Fallout'),
(4, 'Minecraft'),
(5, 'Overwatch'),
(8, 'Podcast'),
(9, 'Pokemon'),
(6, 'Super Mario'),
(7, 'The legend of Zelda'),
(3, 'World of Warcraft');


INSERT INTO `attach_category` (`tag_name`, `category_id`) VALUES
('action', 3),
('action', 5),
('action', 10),
('adventure', 7),
('adventure', 9),
('horror', 10),
('IRL', 8),
('simulation', 5),
('simulation', 6),
('strategy', 5);


INSERT INTO `attach_media` (`tag_name`, `media_id`) VALUES
('fail', 2),
('wow', 1),
('wow', 3);

INSERT INTO `clip` (`id`, `begin`, `end`, `views`, `create_at`, `creator_id`, `media_id`) VALUES
(1, '2019-09-01 06:18:00', '2019-09-01 06:19:00', 2, '2019-09-01 06:20:00', 4, 1);

INSERT INTO `event` (`id`, `name`, `description`, `begin`, `end`, `streamer_id`, `category_id`) VALUES
(1, 'SUPER EVENT', 'A BIG SURPRISE', '2019-09-10 10:00:00', '2019-09-10 14:00:00', 1, 4);

INSERT INTO `follow_category` (`follower_id`, `category_id`) VALUES
(1, 6),
(1, 8),
(2, 4),
(2, 7),
(2, 8),
(3, 10),
(5, 4),
(6, 3);

INSERT INTO `follow_user` (`follower_id`, `streamer_id`, `begin`) VALUES
(2, 1, '2019-08-28 08:00:00'),
(3, 1, '2019-09-02 06:00:00'),
(4, 2, '2019-08-30 08:00:00'),
(4, 5, '2019-09-01 00:00:00'),
(4, 7, '2019-09-01 04:00:00'),
(6, 1, '2019-09-01 04:00:00');

INSERT INTO `friend` (`sender_id`, `receiver_id`, `accepted`) VALUES
(2, 1, 1),
(3, 2, 0),
(6, 4, 1),
(6, 5, 1);

INSERT INTO `subscribe` (`follower_id`, `streamer_id`, `begin`, `tier`) VALUES
(2, 1, '2019-09-02 12:00:00', '2'),
(2, 2, '2019-09-01 22:00:00', '3'),
(4, 2, '2019-08-12 06:00:00', '2'),
(5, 1, '2019-08-22 12:00:00', '3'),
(5, 2, '2019-08-28 00:00:00', '3'),
(6, 1, '2019-09-02 10:00:00', '1');

INSERT INTO `tag` (`name`) VALUES
('action'),
('adventure'),
('card'),
('fail'),
('horror'),
('IRL'),
('puzzle'),
('RPG'),
('simulation'),
('sport'),
('strategy'),
('wow');

INSERT INTO `message` (`id`, `text`, `sent_at`, `sender_id`, `media_id`) VALUES
(1, 'SUPER', '2019-09-02 13:25:08', 3, 3),
(4, 'WOW', '2019-09-02 13:35:35', 6, 1);

SET foreign_key_checks = 1;

