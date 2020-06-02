CREATE DATABASE CustomerSupport

GO

USE CustomerSupport;

CREATE FULLTEXT CATALOG SearchCatalog AS DEFAULT;

GO


CREATE TABLE UserPrincipal (
  UserId BIGINT NOT NULL PRIMARY KEY IDENTITY(1,1),
  Username VARCHAR(30) NOT NULL CONSTRAINT UserPrincipal_Username UNIQUE,
  HashedPassword BINARY(60) NOT NULL,
  AccountNonExpired BIT NOT NULL,
  AccountNonLocked BIT NOT NULL,
  CredentialsNonExpired BIT NOT NULL,
  Enabled BIT NOT NULL,
);

-- Run these statements if the UserPrincipal table doesn't contain these columns
-- ALTER TABLE UserPrincipal
--   ADD COLUMN AccountNonExpired BOOLEAN NOT NULL DEFAULT TRUE,
--   ADD COLUMN AccountNonLocked BOOLEAN NOT NULL DEFAULT TRUE,
--   ADD COLUMN CredentialsNonExpired BOOLEAN NOT NULL DEFAULT TRUE,
--   ADD COLUMN Enabled BOOLEAN NOT NULL DEFAULT TRUE;
-- ALTER TABLE UserPrincipal
--   MODIFY COLUMN AccountNonExpired BOOLEAN NOT NULL,
--   MODIFY COLUMN AccountNonLocked BOOLEAN NOT NULL,
--   MODIFY COLUMN CredentialsNonExpired BOOLEAN NOT NULL,
--   MODIFY COLUMN Enabled BOOLEAN NOT NULL;

CREATE TABLE UserPrincipal_Authority (
  UserId BIGINT NOT NULL,
  Authority VARCHAR(100) NOT NULL,
  CONSTRAINT UserPrincipal_Authority_User_Authority UNIQUE (UserId, Authority),
  CONSTRAINT UserPrincipal_Authority_UserId FOREIGN KEY (UserId)
    REFERENCES UserPrincipal (UserId) ON DELETE CASCADE
);

CREATE TABLE WebServiceClient (
  WebServiceClientId BIGINT NOT NULL PRIMARY KEY IDENTITY(1,1),
  ClientId VARCHAR(50) NOT NULL,
  ClientSecret VARCHAR(60) NOT NULL,
  CONSTRAINT WebServiceClient_ClientId UNIQUE (ClientId)
);

CREATE TABLE WebServiceClient_Scope (
  WebServiceClientId BIGINT NOT NULL,
  Scope VARCHAR(100) NOT NULL,
  CONSTRAINT WebServiceClient_Scopes_Client_Scope UNIQUE (WebServiceClientId, Scope),
  CONSTRAINT WebServiceClient_Scopes_ClientId FOREIGN KEY (WebServiceClientId)
    REFERENCES WebServiceClient (WebServiceClientId) ON DELETE CASCADE
);

CREATE TABLE WebServiceClient_Grant (
  WebServiceClientId BIGINT NOT NULL,
  GrantName VARCHAR(100) NOT NULL,
  CONSTRAINT WebServiceClient_Grants_Client_Grant UNIQUE (WebServiceClientId, GrantName),
  CONSTRAINT WebServiceClient_Grants_ClientId FOREIGN KEY (WebServiceClientId)
    REFERENCES WebServiceClient (WebServiceClientId) ON DELETE CASCADE
);

CREATE TABLE WebServiceClient_RedirectUri (
  WebServiceClientId BIGINT NOT NULL,
  Uri VARCHAR(1024) NOT NULL,
  CONSTRAINT WebServiceClient_Uris_ClientId FOREIGN KEY (WebServiceClientId)
      REFERENCES WebServiceClient (WebServiceClientId) ON DELETE CASCADE
);

CREATE TABLE OAuthAccessToken (
  OAuthAccessTokenId BIGINT NOT NULL PRIMARY KEY IDENTITY(1,1),
  TokenKey VARCHAR(50) NOT NULL,
  Value VARCHAR(50) NOT NULL,
  Expiration smalldatetime NULL,
  Authentication Image NOT NULL,
  CONSTRAINT OAuthAccessToken_TokenKey UNIQUE (TokenKey),
  CONSTRAINT OAuthAccessToken_Value UNIQUE (Value)
);

CREATE TABLE OAuthAccessToken_Scope (
  OAuthAccessTokenId BIGINT NOT NULL,
  Scope VARCHAR(100) NOT NULL,
  CONSTRAINT OAuthAccessToken_Scopes_Token_Scope UNIQUE (OAuthAccessTokenId, Scope),
  CONSTRAINT OAuthAccessToken_Scopes_TokenId FOREIGN KEY (OAuthAccessTokenId)
    REFERENCES OAuthAccessToken (OAuthAccessTokenId) ON DELETE CASCADE
);

CREATE TABLE OAuthNonce (
  OAuthNonceId BIGINT NOT NULL PRIMARY KEY IDENTITY(1,1),
  Value VARCHAR(50),
  NonceTimestamp BIGINT NOT NULL,
  CONSTRAINT OAuthNonce_Value_Timestamp UNIQUE (Value, NonceTimestamp)
);

CREATE TABLE Ticket (
  TicketId BIGINT NOT NULL IDENTITY(1,1) CONSTRAINT Ordered_TicketId PRIMARY KEY ,
  UserId BIGINT NOT NULL,
  Subject VARCHAR(255) NOT NULL,
  Body VARCHAR(640),
  DateCreated smalldatetime NULL,
  CONSTRAINT Ticket_UserId FOREIGN KEY (UserId)
    REFERENCES UserPrincipal (UserId) ON DELETE CASCADE
);

--ALTER TABLE Ticket ADD FULLTEXT INDEX Ticket_Search (Subject, Body);

CREATE TABLE TicketComment (
  CommentId BIGINT NOT NULL IDENTITY(1,1) CONSTRAINT Ordered_CommentId PRIMARY KEY,
  TicketId BIGINT NOT NULL,
  UserId BIGINT NOT NULL,
  Body VARCHAR(640),
  DateCreated smalldatetime NULL,
  CONSTRAINT TicketComment_UserId FOREIGN KEY (UserId)
    REFERENCES UserPrincipal (UserId) ON DELETE NO ACTION,
  CONSTRAINT TicketComment_TicketId FOREIGN KEY (TicketId)
    REFERENCES Ticket (TicketId) ON DELETE NO ACTION
);

--ALTER TABLE TicketComment ADD FULLTEXT INDEX TicketComment_Search (Body);

CREATE FULLTEXT INDEX on TicketComment (Body) KEY INDEX Ordered_CommentId;


CREATE TABLE Attachment (
  AttachmentId BIGINT NOT NULL PRIMARY KEY IDENTITY(1,1),
  AttachmentName VARCHAR(255) NULL,
  MimeContentType VARCHAR(255) NOT NULL,
  Contents Image NOT NULL
);

CREATE TABLE Ticket_Attachment (
  SortKey SMALLINT NOT NULL,
  TicketId BIGINT NOT NULL,
  AttachmentId BIGINT NOT NULL,
  CONSTRAINT Ticket_Attachment_Ticket FOREIGN KEY (TicketId)
    REFERENCES Ticket (TicketId) ON DELETE CASCADE,
  CONSTRAINT Ticket_Attachment_Attachment FOREIGN KEY (AttachmentId)
    REFERENCES Attachment (AttachmentId) ON DELETE CASCADE
);

CREATE INDEX Ticket_OrderedAttachments on Ticket_Attachment (TicketId, SortKey, AttachmentId);

CREATE TABLE TicketComment_Attachment (
  SortKey SMALLINT NOT NULL,
  CommentId BIGINT NOT NULL,
  AttachmentId BIGINT NOT NULL,
  CONSTRAINT TicketComment_Attachment_Comment FOREIGN KEY (CommentId)
    REFERENCES TicketComment (CommentId) ON DELETE CASCADE,
  CONSTRAINT TicketComment_Attachment_Attachment FOREIGN KEY (AttachmentId)
    REFERENCES Attachment (AttachmentId) ON DELETE CASCADE,
  );
  
  CREATE INDEX TicketComment_OrderedAttachments on TicketComment_Attachment (CommentId, SortKey, AttachmentId);

-- Run these statements if the Attachment table already exists with a TicketId column
-- INSERT INTO Ticket_Attachment (SortKey, TicketId, AttachmentId)
--     SELECT @rn := @rn + 1, TicketId, AttachmentId
--         FROM Attachment, (SELECT @rn:=0) x
--         ORDER BY TicketId, AttachmentName;
-- CREATE TEMPORARY TABLE $minSortKeys ENGINE = Memory (
--   SELECT min(SortKey) as SortKey, TicketId FROM Ticket_Attachment GROUP BY TicketId
-- );
-- UPDATE Ticket_Attachment a SET a.SortKey = a.SortKey - (
--   SELECT x.SortKey FROM $minSortKeys x WHERE x.TicketId = a.TicketId
-- ) WHERE TicketId > 0;
-- DROP TABLE $minSortKeys;
-- ALTER TABLE Attachment DROP FOREIGN KEY Attachment_TicketId;
-- ALTER TABLE Attachment DROP COLUMN TicketId;

-- Run these statements to create the default users
INSERT INTO UserPrincipal (Username, HashedPassword, AccountNonExpired,
                           AccountNonLocked, CredentialsNonExpired, Enabled)
VALUES ( -- password
         'admin', CONVERT(BINARY(60), '$2a$10$x0k/yA5qN8SP8JD5CEN.6elEBFxVVHeKZTdyv.RPra4jzRR5SlKSC'),
         1, 1, 1, 1
);

INSERT INTO UserPrincipal_Authority (UserId, Authority)
  VALUES (1, 'VIEW_TICKETS'), (1, 'VIEW_TICKET'), (1, 'CREATE_TICKET'),
    (1, 'EDIT_OWN_TICKET'), (1, 'VIEW_COMMENTS'), (1, 'CREATE_COMMENT'),
    (1, 'EDIT_OWN_COMMENT'), (1, 'VIEW_ATTACHMENT'), (1, 'CREATE_CHAT_REQUEST'),
    (1, 'CHAT');

INSERT INTO UserPrincipal (Username, HashedPassword, AccountNonExpired,
                           AccountNonLocked, CredentialsNonExpired, Enabled)
VALUES ( -- drowssap
         'Sarah', CONVERT(BINARY(60), '$2a$10$JSxmYO.JOb4TT42/4RFzguaTuYkZLCfeND1bB0rzoy7wH0RQFEq8y'),
         1, 1, 1, 1
);
INSERT INTO UserPrincipal_Authority (UserId, Authority)
  VALUES (2, 'VIEW_TICKETS'), (2, 'VIEW_TICKET');

INSERT INTO UserPrincipal (Username, HashedPassword, AccountNonExpired,
                           AccountNonLocked, CredentialsNonExpired, Enabled)
VALUES ( -- wordpass
         'Mike', CONVERT(BINARY(60), '$2a$10$Lc0W6stzND.9YnFRcfbOt.EaCVO9aJ/QpbWnfjJLcMovdTx5s4i3G'),
         1, 1, 1, 1
);
INSERT INTO UserPrincipal_Authority (UserId, Authority)
  VALUES (3, 'VIEW_TICKETS'), (3, 'VIEW_TICKET');

INSERT INTO UserPrincipal (Username, HashedPassword, AccountNonExpired,
                           AccountNonLocked, CredentialsNonExpired, Enabled)
VALUES ( -- green
         'John', CONVERT(BINARY(60), '$2a$10$vacuqbDw9I7rr6RRH8sByuktOzqTheQMfnK3XCT2WlaL7vt/3AMby'),
         1, 1, 1, 1
);
INSERT INTO UserPrincipal_Authority (UserId, Authority)
  VALUES (4, 'VIEW_TICKETS'), (4, 'VIEW_TICKET');

-- Run these statements to add the default OAuth data to the database
INSERT INTO UserPrincipal_Authority (UserId, Authority)
  VALUES (1, 'USE_WEB_SERVICES'), (4, 'USE_WEB_SERVICES');

INSERT INTO WebServiceClient (ClientId, ClientSecret) VALUES ( -- y471l12D2y55U5558rd2
    'TestClient', '$2a$10$elDBcfb/ZKyuNgOPK5.70Oi4gN2EuhU2yONPsoF3avx9.Hd/b8BTa'
);

INSERT INTO WebServiceClient_Scope (WebServiceClientId, Scope)
  VALUES (1, 'READ'), (1, 'WRITE'), (1, 'TRUST');

INSERT INTO WebServiceClient_Grant (WebServiceClientId, GrantName)
  VALUES (1, 'authorization_code');

INSERT INTO WebServiceClient_RedirectUri (WebServiceClientId, Uri)
  VALUES (1, 'http://localhost:8080/client/support');
  
  GO
  
