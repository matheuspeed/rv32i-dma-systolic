class soc_sequencer extends uvm_sequencer #(soc_seq_item);
    `uvm_component_utils(soc_sequencer)

    function new(string name, uvm_component parent);
        super.new(name, parent);
    endfunction
endclass