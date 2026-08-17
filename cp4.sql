
create or REPLACE PACKAGE pkg_pedidos AS 
    --questao 1
    c_desconto_maximo CONSTANT NUMBER := 50;
    g_ultimo_pedido_processado NUMBER;
    
    pedido_nao_encontrado EXCEPTION;
    cliente_inativo EXCEPTION;
    
    PROCEDURE buscar_pedido(p_cod_pedido in NUMBER);
    
    FUNCTION calcular_total_pedido(p_cod_pedido IN NUMBER) RETURN NUMBER;

    PROCEDURE cancelar_pedido( p_cod_pedido IN NUMBER, p_motivo IN VARCHAR2);
END pkg_pedidos;

--sequencia para o nextval funcionar
CREATE SEQUENCE seq_historico
START WITH 2
INCREMENT BY 1
NOCACHE;

--estrutura do package do bosy
CREATE OR REPLACE PACKAGE BODY pkg_pedidos AS
    --questao 2
    FUNCTION calcular_total_pedido(p_cod_pedido IN NUMBER) RETURN NUMBER IS 
        vlr_somando number;
    BEGIN
    SELECT 
        SUM((QTD_ITEM * VAL_UNITARIO_ITEM) - VAL_DESCONTO_ITEM)
    INTO vlr_somando
    FROM ITEM_PEDIDO
    WHERE cod_pedido = p_cod_pedido;
        IF vlr_somando IS NULL THEN
            vlr_somando := 0;
        END IF; 
        UPDATE PEDIDO
        SET VAL_TOTAL_PEDIDO = vlr_somando
        WHERE COD_PEDIDO = p_cod_pedido;
        
        RETURN vlr_somando;
    END calcular_total_pedido;
    --questao 3
    PROCEDURE buscar_pedido(p_cod_pedido in NUMBER) IS
        v_cod_pedido number;
        v_nom_cliente varchar(50);
        v_dat_pedido date;
        v_total_pedido number;
        v_sta_ativo char(1);
    BEGIN
        SELECT
            p.cod_pedido,
            c.nom_cliente,
            p.dat_pedido,
            p.val_total_pedido,
            c.sta_ativo
        INTO
            v_cod_pedido,
            v_nom_cliente,
            v_dat_pedido,
            v_total_pedido,
            v_sta_ativo
        FROM pedido p
            JOIN vendedor v ON p.cod_vendedor = v.cod_vendedor
            JOIN cliente_vendedor cv ON v.cod_vendedor = cv.cod_vendedor
            JOIN cliente c ON cv.cod_cliente = c.cod_cliente
        WHERE p.cod_pedido=p_cod_pedido;
            if v_sta_ativo != 'S' THEN
                RAISE cliente_inativo;
            ELSE
                dbms_output.put_line('Pedido achado: ');
                dbms_output.put_line('Codigo pedido: '||v_cod_pedido);
                dbms_output.put_line('Nome do cliente: '||v_nom_cliente);
                dbms_output.put_line('Data do pedido: '||v_dat_pedido);
                dbms_output.put_line('Total do pedido: '||v_total_pedido);
                g_ultimo_pedido_processado :=v_cod_pedido;
            END IF;
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RAISE pedido_nao_encontrado;
            WHEN OTHERS THEN
                dbms_output.put_line('Erro encontrado');
        END buscar_pedido;
        --questao 4
        PROCEDURE cancelar_pedido(
            p_cod_pedido IN NUMBER,
            p_motivo IN VARCHAR2) 
            IS
            v_dat_cancelamento date;
            v_cod_pedido number;
            v_cod_cliente number;
            v_cod_usuario number;
            v_cod_vendedor number;
            v_dat_pedido date;
            v_dat_entrega date;
            v_total_pedido number;
            v_desconto number;
            v_seq_endereco_cliente number;
        BEGIN
            SELECT 
                DAT_CANCELAMENTO
            INTO 
                v_dat_cancelamento
            FROM PEDIDO
            WHERE
                cod_pedido = p_cod_pedido;
                
            IF v_dat_cancelamento IS NOT NULL THEN
                RAISE_APPLICATION_ERROR(-20201,'Pedido ja cancelado');
            ELSE
                UPDATE pedido
                SET dat_cancelamento=SYSDATE
                WHERE cod_pedido=p_cod_pedido;
                
                select 
                    cod_pedido,
                    cod_cliente,
                    cod_usuario,
                    cod_vendedor,
                    dat_pedido,
                    dat_entrega,
                    val_total_pedido,
                    val_desconto,
                    seq_endereco_cliente
                into
                    v_cod_pedido,
                    v_cod_cliente,
                    v_cod_usuario,
                    v_cod_vendedor,
                    v_dat_pedido,
                    v_dat_entrega,
                    v_total_pedido,
                    v_desconto,
                    v_seq_endereco_cliente
                from pedido
                WHERE cod_pedido= p_cod_pedido;
                
                INSERT INTO historico_pedido(
                    seq_historico_pedido,
                    cod_pedido,
                    cod_cliente,
                    dat_pedido,
                    dat_cancelamento,
                    dat_entrega,
                    val_total_pedido,
                    val_desconto,
                    seq_endereco_cliente,
                    cod_vendedor)
                values
                (
                    seq_historico.NEXTVAL,
                    v_cod_pedido,
                    v_cod_cliente,
                    v_dat_pedido,
                    SYSDATE,
                    v_dat_entrega,
                    v_total_pedido,
                    v_desconto,
                    v_seq_endereco_cliente,
                    v_cod_vendedor
                );
                COMMIT;
            
            END IF;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
                RAISE pedido_nao_encontrado;
        WHEN OTHERS THEN
            dbms_output.put_line(SQLERRM);
            RAISE;
        END cancelar_pedido;
    END pkg_pedidos;
      
