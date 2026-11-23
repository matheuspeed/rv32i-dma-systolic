// Sequence dirigida parametrizável (um bloco, tiling em K, fronteiras e IRQ)
class soc_directed_seq extends uvm_sequence #(soc_seq_item);
    `uvm_object_utils(soc_directed_seq)

    int unsigned array_size = 4;

    function new(string name = "soc_directed_seq");
        super.new(name);
    endfunction

    virtual task body();
        soc_seq_item req;

        // 1. Nominal: 1 bloco SxS, K=8, Polling (IRQ_EN=0)
        req = soc_seq_item::type_id::create("req_nominal");
        start_item(req);
        if (!req.randomize() with { M == array_size; N == array_size; K == 8; irq_en == 0; })
            `uvm_fatal("RAND", "Falha ao randomizar req_nominal")
        finish_item(req);

        // 2. Tiling em M, N e K (> BUF_DEPTH=16) com IRQ_EN=1
        req = soc_seq_item::type_id::create("req_tiled");
        start_item(req);
        if (!req.randomize() with { M == 8; N == 8; K == 24; irq_en == 1; })
            `uvm_fatal("RAND", "Falha ao randomizar req_tiled")
        finish_item(req);

        // 3. Caso de fronteira pior caso: todos -128, K=17 (2 blocos de K)
        req = soc_seq_item::type_id::create("req_boundary_min");
        start_item(req);
        if (!req.randomize() with {
            M == array_size; N == array_size; K == 17; irq_en == 1;
            foreach (A[i]) A[i] == -128;
            foreach (B[i]) B[i] == -128;
        }) `uvm_fatal("RAND", "Falha ao randomizar req_boundary_min")
        finish_item(req);

        // 4. Caso de fronteira: matriz zero, K=1
        req = soc_seq_item::type_id::create("req_zero");
        start_item(req);
        if (!req.randomize() with {
            M == array_size; N == array_size; K == 1; irq_en == 0;
            foreach (A[i]) A[i] == 0;
            foreach (B[i]) B[i] == 0;
        }) `uvm_fatal("RAND", "Falha ao randomizar req_zero")
        finish_item(req);
    endtask
endclass

// Sequence aleatória com restrições para regressão e cobertura
class soc_random_seq extends uvm_sequence #(soc_seq_item);
    `uvm_object_utils(soc_random_seq)

    rand int unsigned num_txns   = 15;
    int unsigned      array_size = 4;

    function new(string name = "soc_random_seq");
        super.new(name);
    endfunction

    virtual task body();
        soc_seq_item req;
        repeat (num_txns) begin
            req = soc_seq_item::type_id::create("req_rand");
            start_item(req);
            if (!req.randomize() with {
                (M % array_size) == 0;
                (N % array_size) == 0;
            }) `uvm_fatal("RAND", "Falha ao randomizar req_rand")
            finish_item(req);
        end
    endtask
endclass