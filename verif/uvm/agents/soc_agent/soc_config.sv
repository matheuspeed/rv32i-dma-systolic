class soc_config extends uvm_object;
    `uvm_object_utils(soc_config)

    virtual soc_if            vif;
    uvm_active_passive_enum   is_active      = UVM_ACTIVE;
    int unsigned              array_size     = 4;
    int unsigned              timeout_cycles = 50000;

    function new(string name = "soc_config");
        super.new(name);
    endfunction
endclass