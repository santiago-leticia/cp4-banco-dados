--RM565799 - LETICIA SANTIAGO E SILVA
--RM564992 - NATAN FREITAS DE MORAES


SET SERVEROUTPUT ON;
SET VERIFY OFF;

 --questao 1
create or REPLACE PACKAGE pkg_pedidos AS 
    c_desconto_maximo CONSTANT NUMBER := 50;
    g_ultimo_pedido_processado NUMBER;
    
    pedido_nao_encontrado EXCEPTION;
    cliente_inativo EXCEPTION;
    
    PROCEDURE buscar_pedido(p_cod_pedido in NUMBER);
    
    FUNCTION calcular_total_pedido(p_cod_pedido IN NUMBER) RETURN NUMBER;

    PROCEDURE cancelar_pedido( p_cod_pedido IN NUMBER, p_motivo IN VARCHAR2);
    --exercicio7
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

--- EXERCICIO 5
CREATE OR REPLACE PACKAGE pkg_auditoria AS
    PROCEDURE registrar_cancelamento;
    
    PROCEDURE registrar_consulta;

    FUNCTION obter_resumo_sessao RETURN VARCHAR2;
END pkg_auditoria;
/
--exercicio 6 
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

--sequencia para o nextval funcionar, deve fazer esse processo em ambos
--esse é para cancelar o pedido e gerar a sequencia de id corretar
CREATE SEQUENCE seq_historico
START WITH 1
INCREMENT BY 1;
--esse é para o sequencia de movimentacao para dar baixar estoque
CREATE SEQUENCE seq_movimento
START WITH 1
INCREMENT BY 1;

--estrutura do package do body da cp4
--o body do mesmo nome, nao podem ficar separado se nao dar erro

CREATE OR REPLACE PACKAGE BODY pkg_pedidos AS
    --questao 2
    FUNCTION calcular_total_pedido(p_cod_pedido IN NUMBER) RETURN NUMBER IS 
        vlr_somando number;
    BEGIN
        SELECT 
            SUM((QTD_ITEM * VAL_UNITARIO_ITEM) - VAL_DESCONTO_ITEM)
        INTO vlr_somando
        FROM item_pedido
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
            JOIN cliente c ON p.cod_cliente = c.cod_cliente
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
                dbms_output.put_line('O pedido foi cancelado');

            END IF;
        EXCEPTION
        WHEN NO_DATA_FOUND THEN
                RAISE pedido_nao_encontrado;
        WHEN OTHERS THEN
            dbms_output.put_line(SQLERRM);
            RAISE;
        END cancelar_pedido;
        --exercicio 7
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
    
--body do exercicio 5
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
--- body do 6
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
--Parte de Testes
--Calcular o total presente do pedido questao 2
DECLARE
    v_produto NUMBER;
    BEGIN
        v_produto := pkg_pedidos.calcular_total_pedido(130513);
        dbms_output.put_line('Valor total do pedido: '||v_produto);
END;
/

--Teste do procurar pedido - questao 3 
DECLARE
    BEGIN
        pkg_pedidos.buscar_pedido(130513);
    END;
/

--Cancelar pedido presente - questao 4
DECLARE 
    BEGIN
        pkg_pedidos.cancelar_pedido(130508,'Demorar presente no produto');
    END;
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

-- TESTE EXERCICIO 6
SELECT pkg_estoque.obter_saldo_estoque(10, 1) FROM dual;

-- TESTES EXERCICIO 7
BEGIN
    pkg_pedidos.listar_itens_pedido(130519);
    pkg_pedidos.listar_itens_pedido(1);
END;
/
 
-- TESTE EXERCICIO 8
DECLARE
    v_valor_desconto NUMBER;
    v_novo_total NUMBER;
BEGIN
 
    pkg_pedidos.calcular_desconto_pedido(
        130519,
        10,
        v_valor_desconto,
        v_novo_total
    );
 
    DBMS_OUTPUT.PUT_LINE(
        'Valor do desconto: ' || v_valor_desconto
    );
 
    DBMS_OUTPUT.PUT_LINE(
        'Novo total: ' || v_novo_total
    );
 
END;
/
      
