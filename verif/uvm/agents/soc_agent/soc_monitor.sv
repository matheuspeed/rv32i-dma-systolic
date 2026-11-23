class soc_monitor extends uvm_monitor;
    `uvm_component_utils(soc_monitor)

    soc_config cfg;
    uvm_analysis_port #(soc_seq_item) ap;

    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap = new("ap", this);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(soc_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOVIF", "soc_config nao encontrado no uvm_config_db")
    endfunction

    virtual task run_phase(uvm_phase phase);
        logic [11:0] obs_addr_a, obs_addr_b, obs_addr_c;
        int unsigned obs_m, obs_n, obs_k;
        bit          obs_irq_en;
        int unsigned cyc;
        soc_seq_item tr;

        forever begin
            @(posedge cfg.vif.clk);
            if (!cfg.vif.rst && cfg.vif.dbus_we && cfg.vif.dbus_addr[16]) begin
                case (cfg.vif.dbus_addr[7:0])
                    8'h08: obs_addr_a = cfg.vif.dbus_wdata[11:0];
                    8'h0C: obs_addr_b = cfg.vif.dbus_wdata[11:0];
                    8'h10: obs_addr_c = cfg.vif.dbus_wdata[11:0];
                    8'h14: obs_m      = cfg.vif.dbus_wdata;
                    8'h18: obs_n      = cfg.vif.dbus_wdata;
                    8'h1C: obs_k      = cfg.vif.dbus_wdata;
                    8'h00: begin
                        obs_irq_en = cfg.vif.dbus_wdata[1];
                        if (cfg.vif.dbus_wdata[0]) begin
                            // CPU disparou CTRL.START = 1; mede latência até o término
                            cyc = 0;
                            while (cyc < cfg.timeout_cycles) begin
                                @(posedge cfg.vif.clk);
                                cyc++;
                                if (obs_irq_en && cfg.vif.irq === 1'b1)
                                    break;
                                if (!obs_irq_en && cfg.vif.dbus_we && !cfg.vif.dbus_addr[16] &&
                                    (cfg.vif.dbus_addr[11:0] == 12'h01C))
                                    break;
                            end

                            tr = soc_seq_item::type_id::create("tr");
                            tr.M              = obs_m;
                            tr.N              = obs_n;
                            tr.K              = obs_k;
                            tr.irq_en         = obs_irq_en;
                            tr.addr_a         = obs_addr_a;
                            tr.addr_b         = obs_addr_b;
                            tr.addr_c         = obs_addr_c;
                            tr.latency_cycles = cyc;
                            tr.array_size_cfg = cfg.array_size;

                            tr.A = new[obs_m * obs_k];
                            tr.B = new[obs_k * obs_n];
                            tr.C = new[obs_m * obs_n];

                            foreach (tr.A[i]) tr.A[i] = signed'(cfg.vif.read_dmem_byte(obs_addr_a + i[11:0]));
                            foreach (tr.B[i]) tr.B[i] = signed'(cfg.vif.read_dmem_byte(obs_addr_b + i[11:0]));
                            foreach (tr.C[i]) tr.C[i] = signed'(cfg.vif.read_dmem_word(obs_addr_c + (i[11:0] * 4)));

                            `uvm_info("MON", $sformatf("Operacao concluida: %s", tr.convert2string()), UVM_MEDIUM)
                            ap.write(tr);
                        end
                    end
                    default: ;
                endcase
            end
        end
    endtask
endclass