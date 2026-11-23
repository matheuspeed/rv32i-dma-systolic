class soc_base_test extends uvm_test;
    `uvm_component_utils(soc_base_test)

    soc_env    env;
    soc_config cfg;

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction

    virtual function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        cfg = soc_config::type_id::create("cfg");

        if (!uvm_config_db#(virtual soc_if)::get(this, "", "vif", cfg.vif))
            `uvm_fatal("NOVIF", "virtual soc_if nao encontrado no uvm_config_db")

        void'(uvm_config_db#(int unsigned)::get(this, "", "array_size", cfg.array_size));
        cfg.is_active = UVM_ACTIVE;

        uvm_config_db#(soc_config)::set(this, "env.agent*", "cfg", cfg);
        env = soc_env::type_id::create("env", this);
    endfunction

    virtual function void end_of_elaboration_phase(uvm_phase phase);
        super.end_of_elaboration_phase(phase);
        uvm_top.print_topology();
    endfunction
endclass