SET SERVEROUTPUT ON;
SET VERIFY OFF;

--- EXERCICIO 5
CREATE OR REPLACE PACKAGE pkg_auditoria AS
    PROCEDURE registrar_cancelamento;
    
    PROCEDURE registrar_consulta;

    FUNCTION obter_resumo_sessao RETURN VARCHAR2;
END pkg_auditoria;
/

CREATE OR REPLACE PACKAGE BODY pkg_auditoria AS
    g_total_pedidos_cancelados NUMBER :=0;
    g_total_pedidos_consultados NUMBER := 0;
    
    PROCEDURE registrar_cancelamento IS
    BEGIN
        g_total_pedidos_cancelados := g_total_pedidos_cancelados + 1;
    END registrar_cancelamento;
    
    PROCEDURE registrar_consulta IS
    BEGIN
        g_total_pedidos_consultados := g_total_pedidos_consultados + 1;
    END registrar_consulta;

    FUNCTION obter_resumo_sessao RETURN VARCHAR2 IS
    BEGIN
        RETURN 'Cancelamentos: '||g_total_pedidos_cancelados||' | Consultas: '||g_total_pedidos_consultados;
    END obter_resumo_sessao;

END pkg_auditoria;
/

-- TESTES DO EXERCICIO 5
DECLARE
    v_resumo VARCHAR2(200);
BEGIN
    v_resumo := pkg_auditoria.obter_resumo_sessao;
    DBMS_OUTPUT.PUT_LINE(v_resumo);
    
    pkg_auditoria.registrar_consulta;
    pkg_auditoria.registrar_consulta;
    pkg_auditoria.registrar_cancelamento;
    pkg_auditoria.registrar_cancelamento;
    pkg_auditoria.registrar_cancelamento;

    v_resumo := pkg_auditoria.obter_resumo_sessao;
    DBMS_OUTPUT.PUT_LINE(v_resumo);
END;
/

--- EXERCICIO 6
CREATE OR REPLACE PACKAGE pkg_estoque AS

    estoque_insuficiente EXCEPTION;
    PRAGMA EXCEPTION_INIT(estoque_insuficiente, -20301);

    FUNCTION obter_saldo_estoque(
        p_cod_produto IN NUMBER,
        p_cod_estoque IN NUMBER
    ) RETURN NUMBER;

    PROCEDURE dar_baixa_estoque(
        p_cod_produto IN NUMBER,
        p_cod_estoque IN NUMBER,
        p_quantidade IN NUMBER
    );

END pkg_estoque;
/

CREATE SEQUENCE seq_movimento
START WITH 1
INCREMENT BY 1;

CREATE OR REPLACE PACKAGE BODY pkg_estoque AS

    FUNCTION obter_saldo_estoque(
        p_cod_produto IN NUMBER,
        p_cod_estoque IN NUMBER
    ) RETURN NUMBER
    IS
        v_qnt_produto NUMBER;
    BEGIN
        SELECT SUM(QTD_PRODUTO) INTO v_qnt_produto FROM ESTOQUE_PRODUTO WHERE COD_PRODUTO = p_cod_produto AND COD_ESTOQUE = p_cod_estoque;
        
        IF v_qnt_produto IS NULL THEN
            v_qnt_produto := 0;
        END IF;
        
        RETURN v_qnt_produto;
    END obter_saldo_estoque;
    
    PROCEDURE dar_baixa_estoque(
        p_cod_produto IN NUMBER,
        p_cod_estoque IN NUMBER,
        p_quantidade IN NUMBER
    )
    IS
        v_qnt_produto NUMBER;
    BEGIN
        v_qnt_produto := obter_saldo_estoque(
            p_cod_produto,
            p_cod_estoque
        );

        IF v_qnt_produto < p_quantidade THEN
            RAISE_APPLICATION_ERROR(
                -20301,
                'Quantidade em estoque insuficiente para o produto ' || p_cod_produto
            );
        END IF;

        INSERT INTO MOVIMENTO_ESTOQUE (
            SEQ_MOVIMENTO_ESTOQUE,
            COD_PRODUTO,
            DAT_MOVIMENTO_ESTOQUE,
            QTD_MOVIMENTACAO_ESTOQUE,
            COD_TIPO_MOVIMENTO_ESTOQUE
        )
        VALUES (
            seq_movimento.NEXTVAL,
            p_cod_produto,
            SYSDATE,
            p_quantidade,
            2
        );

        UPDATE ESTOQUE_PRODUTO SET QTD_PRODUTO = QTD_PRODUTO - p_quantidade WHERE COD_PRODUTO = p_cod_produto AND COD_ESTOQUE = p_cod_estoque;

    END dar_baixa_estoque;
END pkg_estoque;
/

-- TESTE EXERCICIO 6
SELECT pkg_estoque.obter_saldo_estoque(10, 1) FROM dual;

-- EXERCICIO 7
CREATE OR REPLACE PACKAGE pkg_pedidos AS

    pedido_nao_encontrado EXCEPTION;
    
    c_desconto_maximo NUMBER := 50;
    
    PROCEDURE listar_itens_pedido(
        p_cod_pedido IN NUMBER
    );
    
    PROCEDURE calcular_desconto_pedido( 
        p_cod_pedido IN NUMBER, 
        p_percentual IN NUMBER, 
        p_valor_desconto OUT NUMBER, 
        p_novo_total OUT NUMBER 
    );

END pkg_pedidos;
/

CREATE OR REPLACE PACKAGE BODY pkg_pedidos AS

    PROCEDURE listar_itens_pedido(
        p_cod_pedido IN NUMBER
    )
    IS
        CURSOR c_itens IS
            SELECT
                ip.COD_ITEM_PEDIDO,
                p.NOM_PRODUTO,
                ip.QTD_ITEM,
                ip.VAL_UNITARIO_ITEM,
                ip.VAL_DESCONTO_ITEM,
                (ip.QTD_ITEM * ip.VAL_UNITARIO_ITEM
                 - ip.VAL_DESCONTO_ITEM) AS VALOR_LIQUIDO
            FROM ITEM_PEDIDO ip
            INNER JOIN PRODUTO p
                ON p.COD_PRODUTO = ip.COD_PRODUTO
            WHERE ip.COD_PEDIDO = p_cod_pedido;

        v_total_itens NUMBER := 0;
        v_tem_itens BOOLEAN := FALSE;
        
    BEGIN
        FOR item IN c_itens LOOP
            v_tem_itens := TRUE;
            DBMS_OUTPUT.PUT_LINE(
                'Item: ' || item.COD_ITEM_PEDIDO ||
                ' | Produto: ' || item.NOM_PRODUTO ||
                ' | Quantidade: ' || item.QTD_ITEM ||
                ' | Valor unitário: ' || item.VAL_UNITARIO_ITEM ||
                ' | Desconto: ' || item.VAL_DESCONTO_ITEM ||
                ' | Valor líquido: ' || item.VALOR_LIQUIDO
            );
            v_total_itens := v_total_itens + item.VALOR_LIQUIDO;
        END LOOP;

        IF v_tem_itens = FALSE THEN
            DBMS_OUTPUT.PUT_LINE('Pedido sem itens cadastrados.');
            RAISE pedido_nao_encontrado;
        END IF;
        
        DBMS_OUTPUT.PUT_LINE(
            'Total geral dos itens: ' || v_total_itens
        );

    EXCEPTION
        WHEN pedido_nao_encontrado THEN
            DBMS_OUTPUT.PUT_LINE('Pedido não encontrado.');
    END listar_itens_pedido;
-- EXERCICIO 8
    PROCEDURE calcular_desconto_pedido(
        p_cod_pedido IN NUMBER,
        p_percentual IN NUMBER,
        p_valor_desconto OUT NUMBER,
        p_novo_total OUT NUMBER
    )
    IS
        v_val_total_pedido NUMBER;
    BEGIN
        SELECT VAL_TOTAL_PEDIDO INTO v_val_total_pedido FROM PEDIDO WHERE COD_PEDIDO = p_cod_pedido;

        IF p_percentual < 0 OR p_percentual > c_desconto_maximo THEN -- c_desconto_maximo é especificada no ex 1 (testar depois)
            RAISE_APPLICATION_ERROR(-20401, 'Desconto superior ao maximo permitido: ' ||c_desconto_maximo || '%');
        END IF;

        p_valor_desconto := v_val_total_pedido * (p_percentual / 100);
        p_novo_total := v_val_total_pedido - p_valor_desconto;

        UPDATE PEDIDO SET VAL_DESCONTO = p_valor_desconto, VAL_TOTAL_PEDIDO = p_novo_total WHERE COD_PEDIDO = p_cod_pedido;
    END calcular_desconto_pedido;
END pkg_pedidos;
/



INSERT INTO cliente SELECT * FROM pf1788.cliente;
INSERT INTO estoque SELECT * FROM pf1788.estoque;
INSERT INTO tipo_movimento_estoque SELECT * FROM pf1788.tipo_movimento_estoque;
INSERT INTO produto SELECT * FROM pf1788.produto;
INSERT INTO estoque_produto SELECT * FROM pf1788.estoque_produto;
INSERT INTO movimento_estoque SELECT * FROM pf1788.movimento_estoque;
INSERT INTO usuario SELECT * FROM pf1788.usuario;
INSERT INTO vendedor SELECT * FROM pf1788.vendedor;
INSERT INTO cliente_vendedor SELECT * FROM pf1788.cliente_vendedor;
-- INSERT INTO pedido SELECT * FROM pf1788.pedido; -- ERRO TOO MANY VALUES
INSERT INTO pedido (
    COD_PEDIDO,
    COD_PEDIDO_RELACIONADO,
    COD_CLIENTE,
    COD_USUARIO,
    COD_VENDEDOR,
    DAT_PEDIDO,
    DAT_CANCELAMENTO,
    DAT_ENTREGA,
    VAL_TOTAL_PEDIDO,
    VAL_DESCONTO,
    SEQ_ENDERECO_CLIENTE
)
SELECT
    COD_PEDIDO,
    COD_PEDIDO_RELACIONADO,
    COD_CLIENTE,
    COD_USUARIO,
    COD_VENDEDOR,
    DAT_PEDIDO,
    DAT_CANCELAMENTO,
    DAT_ENTREGA,
    VAL_TOTAL_PEDIDO,
    VAL_DESCONTO,
    SEQ_ENDERECO_CLIENTE
FROM pf1788.pedido;
INSERT INTO item_pedido SELECT * FROM pf1788.item_pedido;