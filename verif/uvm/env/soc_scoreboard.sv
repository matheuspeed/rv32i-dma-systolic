class soc_scoreboard extends uvm_scoreboard;
    `uvm_component_utils(soc_scoreboard)

    uvm_tlm_analysis_fifo #(soc_seq_item) obs_fifo;
    uvm_tlm_analysis_fifo #(soc_seq_item) exp_fifo;

    int unsigned total_ops   = 0;
    int unsigned passed_ops  = 0;
    int unsigned failed_ops  = 0;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        obs_fifo = new("obs_fifo", this);
        exp_fifo = new("exp_fifo", this);
    endfunction

    virtual task run_phase(uvm_phase phase);
        soc_seq_item obs, exp;
        bit          mismatch;

        forever begin
            obs_fifo.get(obs);
            exp_fifo.get(exp);
            total_ops++;
            mismatch = 0;

            if (obs.C.size() != exp.C.size()) begin
                `uvm_error("SCB", $sformatf("Tamanho divergente: obtido=%0d esperado=%0d",
                                            obs.C.size(), exp.C.size()))
                mismatch = 1;
            end else begin
                for (int unsigned i = 0; i < exp.M; i++) begin
                    for (int unsigned j = 0; j < exp.N; j++) begin
                        int unsigned idx = i * exp.N + j;
                        if (obs.C[idx] !== exp.C[idx]) begin
                            `uvm_error("SCB", $sformatf(
                                "Divergencia na op #%0d [%0dx%0dx%0d] C[%0d][%0d]: esperado=0x%08h (%0d), obtido=0x%08h (%0d)",
                                total_ops, exp.M, exp.N, exp.K, i, j,
                                exp.C[idx], exp.C[idx], obs.C[idx], obs.C[idx]))
                            mismatch = 1;
                        end
                    end
                end
            end

            if (mismatch) begin
                failed_ops++;
            end else begin
                passed_ops++;
                `uvm_info("SCB", $sformatf("PASS op #%0d: %s", total_ops, obs.convert2string()), UVM_LOW)
            end
        end
    endtask

    virtual function void check_phase(uvm_phase phase);
        super.check_phase(phase);
        if (!obs_fifo.is_empty() || !exp_fifo.is_empty())
            `uvm_error("SCB", $sformatf("Operacoes pendentes sem comparacao! obs=%0d exp=%0d",
                                        obs_fifo.used(), exp_fifo.used()))
    endfunction

    virtual function void report_phase(uvm_phase phase);
        uvm_report_server srv;
        int unsigned err_cnt;
        super.report_phase(phase);

        srv     = uvm_report_server::get_server();
        err_cnt = srv.get_severity_count(UVM_ERROR) + srv.get_severity_count(UVM_FATAL);

        $display("=================================================================");
        $display(" RESUMO SCOREBOARD: Total=%0d | Acertos=%0d | Divergencias=%0d",
                 total_ops, passed_ops, failed_ops);
        $display(" UVM_ERROR=%0d | UVM_FATAL=%0d",
                 srv.get_severity_count(UVM_ERROR), srv.get_severity_count(UVM_FATAL));
        if ((err_cnt == 0) && (failed_ops == 0) && (total_ops > 0))
            $display(" >>> TEST PASS <<<");
        else
            $display(" >>> TEST FAIL <<<");
        $display("=================================================================");
    endfunction
endclass