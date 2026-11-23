class soc_driver extends uvm_driver #(soc_seq_item);
    `uvm_component_utils(soc_driver)

    soc_config cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(soc_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOVIF", "soc_config nao encontrado no uvm_config_db")
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_seq_item req;
        cfg.vif.rst <= 1'b1;
        repeat (2) @(negedge cfg.vif.clk);

        forever begin
            seq_item_port.get_next_item(req);
            drive_transaction(req);
            seq_item_port.item_done();
        end
    endtask

    virtual task drive_transaction(soc_seq_item req);
        int unsigned timeout_cnt;

        // Mantém CPU e DMA em reset enquanto carrega a DMEM via backdoor
        cfg.vif.rst <= 1'b1;
        @(negedge cfg.vif.clk);

        // Preenche a região de saída C com um marcador para evitar falsos positivos:
        // se o DMA não gravar algum elemento, o marcador aparece no scoreboard
        // (com 0, um teste de matriz zero passaria mesmo sem nenhuma escrita).
        for (int idx = 0; idx < (req.M * req.N); idx++)
            cfg.vif.write_dmem_word(req.addr_c + (idx * 4), 32'hDEADBEEF);

        // Escreve tabela de descritores em 0x000..0x018
        cfg.vif.write_dmem_word(12'h000, {20'b0, req.addr_a});
        cfg.vif.write_dmem_word(12'h004, {20'b0, req.addr_b});
        cfg.vif.write_dmem_word(12'h008, {20'b0, req.addr_c});
        cfg.vif.write_dmem_word(12'h00C, req.M);
        cfg.vif.write_dmem_word(12'h010, req.N);
        cfg.vif.write_dmem_word(12'h014, req.K);
        cfg.vif.write_dmem_word(12'h018, {31'b0, req.irq_en});

        // Carrega matrizes A e B
        foreach (req.A[i]) cfg.vif.write_dmem_byte(req.addr_a + i[11:0], req.A[i]);
        foreach (req.B[i]) cfg.vif.write_dmem_byte(req.addr_b + i[11:0], req.B[i]);

        // Libera reset para o firmware executar
        @(negedge cfg.vif.clk);
        cfg.vif.rst <= 1'b0;

        // Aguarda término da operação (via irq ou escrita de conclusão do firmware em 0x01C)
        timeout_cnt = 0;
        while (timeout_cnt < cfg.timeout_cycles) begin
            @(posedge cfg.vif.clk);
            timeout_cnt++;
            if (req.irq_en && cfg.vif.irq === 1'b1)
                break;
            if (!req.irq_en && cfg.vif.dbus_we && !cfg.vif.dbus_addr[16] &&
                (cfg.vif.dbus_addr[11:0] == 12'h01C))
                break;
        end

if (timeout_cnt >= cfg.timeout_cycles)
            `uvm_fatal("TIMEOUT", $sformatf("Timeout (%0d ciclos) em %s | DBUS_ADDR=0x%08h DBUS_WE=%0b ACC_BUSY=%0b IRQ=%0b",
                                            cfg.timeout_cycles, req.convert2string(),
                                            cfg.vif.dbus_addr, cfg.vif.dbus_we,
                                            cfg.vif.acc_busy, cfg.vif.irq))

        // Aguarda 2 ciclos extras para estabilização antes da próxima transação
        repeat (2) @(posedge cfg.vif.clk);
    endtask
endclass