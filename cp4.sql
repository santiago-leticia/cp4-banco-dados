create or REPLACE PACKAGE BODY pkg_pedidos AS 
    //Vai apresetar o valor maior do desconto
    FUNCTION conta_desconto RETURN NUMBER IS
        c_desconto NUMBER;
    BEGIN
        SELECT 
            MAX(val_desconto)
        INTO c_desconto
        FROM
            pedido;
            
        RETURN c_desconto;
    END conta_desconto;
    //Vai servir a questao de ver qual foi o ultimo processado
    FUNCTION dt_ultima_processada RETURN NUMBER IS
        g_ultmo_pedido_processado NUMBER;
    BEGIN
        SELECT 
            COD_PEDIDO,
        into
            g_ultmo_pedido_processado
        from
            pedido
            ORDER BY cod_pedido DESC
        FETCH FIRST 1 ROWS ONLY;
    RETURN g_ultmo_pedido_processado;
    //Pedido nao encontrado
    FUNCTION pedido_nao_encotrado RETURN NUMBER IS
        nr_procurar NUMBER;
        fg_achado NUMBER;
    BEGIN
        SELECT 
            cod_pedido
        INTO 
            fg_achado
        from 
            pedido
        where
            cod_pedido=nr_procurar;
            
        
        
        
    
    
END pkg_pedidos;
