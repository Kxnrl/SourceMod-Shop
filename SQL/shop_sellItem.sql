CREATE PROCEDURE `shop_sellItem`
(
IN
    userId INT(11),
    dbIndex INT(11),
    price INT(11),
    reason VARCHAR(256)
)

SQL SECURITY INVOKER BEGIN

    DECLARE result_code TINYINT(3);
    
    DECLARE EXIT handler FOR SQLEXCEPTION
        BEGIN
            ROLLBACK;
            SET result_code = -2;
            SELECT price, result_code;
        END;

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

            SET result_code = 0;

        ELSE 

            /* tell plugin failure */
            SET result_code = -1;

        END IF;
        
    COMMIT;

    SELECT price, result_code;

END;