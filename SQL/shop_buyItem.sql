CREATE PROCEDURE `shop_buyItem`
(
IN
    userId INT(11),
    uniqueId VARCHAR(256),
    price INT(11),
    expiration INT(11),
    reason VARCHAR(256)
)

SQL SECURITY INVOKER BEGIN

    DECLARE dbIndex INT(11) DEFAULT -1;
    DECLARE logCost INT(11) DEFAULT 0;

    DECLARE EXIT handler FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SET dbIndex = -2;
            SELECT dbIndex, logCost;
        END;

    START TRANSACTION;

        SET logCost = 0 - `price`;

        /* UPDATE Cost */
        UPDATE  `dxg_users`
        SET     `money` = `money` - `price`
        WHERE   `uid` = `userId`;

        IF (ROW_COUNT() <> 0) THEN
            
            /* INSERT Item */
            INSERT INTO `dxg_inventory`
            VALUES (DEFAULT, `userId`, `uniqueId`, `price`, UNIX_TIMESTAMP(), `expiration`);

            /* GET INSERT ID */
            SET dbIndex = LAST_INSERT_ID();

            /* LOGGING */
            INSERT INTO `dxg_banklog`
            VALUES (DEFAULT, `userId`, `logCost`, `reason`, UNIX_TIMESTAMP());

        ELSE 

            /* tell plugin failure */
            SET dbIndex = -1;

        END IF;

    COMMIT;

    SELECT dbIndex, logCost;

END;