class soc_agent extends uvm_agent;
    `uvm_component_utils(soc_agent)

    soc_config    cfg;
    soc_sequencer sqr;
    soc_driver    drv;
    soc_monitor   mon;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if (!uvm_config_db#(soc_config)::get(this, "", "cfg", cfg))
            `uvm_fatal("NOCFG", "soc_config nao encontrado no uvm_config_db")

        mon = soc_monitor::type_id::create("mon", this);
        if (cfg.is_active == UVM_ACTIVE) begin
            sqr = soc_sequencer::type_id::create("sqr", this);
            drv = soc_driver::type_id::create("drv", this);
        end
    endfunction

    virtual function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        if (cfg.is_active == UVM_ACTIVE)
            drv.seq_item_port.connect(sqr.seq_item_export);
    endfunction
endclass