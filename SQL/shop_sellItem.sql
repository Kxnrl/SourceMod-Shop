CREATE PROCEDURE `shop_sellItem`
(
IN
    userId INT(11),
    dbIndex INT(11),
    price INT(11),
    reason VARCHAR(256)
)

SQL SECURITY INVOKER

BEGIN

DECLARE result_code TINYINT(3);

START TRANSACTION;

    DELETE FROM `dxg_inventory`
    WHERE
            `id` = `dbIndex`
        AND
            `uid` = `userId`;

    

    IF (ROW_COUNT() > 0) THEN

        /* UPDATE Money */
        UPDATE  `dxg_users`
        SET     `money` = `money` + `price`
        WHERE   `uid` = `userId`;

        /* LOGGING */
        INSERT INTO `dxg_banklog`
        VALUES (DEFAULT, `userId`, `price`, `reason`, UNIX_TIMESTAMP());
        
        COMMIT;

        SET result_code = 0;

    ELSE 

        /* rollback */
        ROLLBACK;
    
        /* tell plugin failure */
        SET result_code = -1;

    END IF;

    SELECT price, result_code;

END;