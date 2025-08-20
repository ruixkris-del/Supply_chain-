// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/*
    Sistema de Cadena de Suministro (Totalmente en Español)
    - Identificadores en camelCase
    - Comentarios y mensajes en español
    - Estructura modular: NucleoCadena + Inventario + Produccion + Logistica + Pagos + Auditoria
*/

/* ------------------------------------------------------------------
   CONTRATO NÚCLEO: NucleoCadena
   - Administra direcciones de los módulos
   - Solo el propietario puede registrar/actualizar contratos
   ------------------------------------------------------------------ */
contract NucleoCadena {
    address public propietario;

    // Direcciones de módulos (camelCase)
    address public direccionInventario;
    address public direccionProduccion;
    address public direccionLogistica;
    address public direccionPagos;
    address public direccionAuditoria;

    // Eventos para seguimiento
    event ContratoInventarioEstablecido(address indexed direccion);
    event ContratoProduccionEstablecido(address indexed direccion);
    event ContratoLogisticaEstablecido(address indexed direccion);
    event ContratoPagosEstablecido(address indexed direccion);
    event ContratoAuditoriaEstablecido(address indexed direccion);

    constructor() {
        propietario = msg.sender;
    }

    modifier soloPropietario() {
        require(msg.sender == propietario, "Solo el propietario puede ejecutar");
        _;
    }

    // Funciones para enlazar módulos (solo propietario)
    function setDireccionInventario(address _direccion) external soloPropietario {
        direccionInventario = _direccion;
        emit ContratoInventarioEstablecido(_direccion);
    }

    function setDireccionProduccion(address _direccion) external soloPropietario {
        direccionProduccion = _direccion;
        emit ContratoProduccionEstablecido(_direccion);
    }

    function setDireccionLogistica(address _direccion) external soloPropietario {
        direccionLogistica = _direccion;
        emit ContratoLogisticaEstablecido(_direccion);
    }

    function setDireccionPagos(address _direccion) external soloPropietario {
        direccionPagos = _direccion;
        emit ContratoPagosEstablecido(_direccion);
    }

    function setDireccionAuditoria(address _direccion) external soloPropietario {
        direccionAuditoria = _direccion;
        emit ContratoAuditoriaEstablecido(_direccion);
    }
}

/* ------------------------------------------------------------------
   INTERFACES (en español)
   - Para llamadas entre contratos
   ------------------------------------------------------------------ */
interface IInventario {
    function existeProducto(uint256 productoId) external view returns (bool);
    function obtenerStock(uint256 productoId) external view returns (uint256);
    function reducirStock(uint256 productoId, uint256 cantidad) external;
    function aumentarStock(uint256 productoId, uint256 cantidad) external;
}

/* ------------------------------------------------------------------
   CONTRATO: Auditoria
   - Permite que los módulos enlazados en NucleoCadena registren eventos
   - Evita que direcciones no enlazadas escriban en auditoría
   ------------------------------------------------------------------ */
contract Auditoria {
    address public direccionNucleo; // dirección del contrato NucleoCadena

    event EventoAuditoria(address indexed origen, string tipoEvento, string descripcion, uint256 fecha);

    modifier soloNucleoOModuloEnlazado() {
        // Permitir llamadas desde el núcleo o desde cualquiera de los módulos enlazados en el núcleo
        if (msg.sender == direccionNucleo) {
            _;
            return;
        }
        require(direccionNucleo != address(0), "Nucleo no inicializado");
        NucleoCadena nucleo = NucleoCadena(direccionNucleo);

        // Verificamos que el caller sea alguna de las direcciones enlazadas (inventario, produccion, logistica, pagos)
        require(
            msg.sender == nucleo.direccionInventario() ||
            msg.sender == nucleo.direccionProduccion() ||
            msg.sender == nucleo.direccionLogistica() ||
            msg.sender == nucleo.direccionPagos() ||
            msg.sender == nucleo.direccionAuditoria(),
            "Direccion no autorizada para auditar"
        );
        _;
    }

    constructor(address _direccionNucleo) {
        require(_direccionNucleo != address(0), "Direccion nucleo invalida");
        direccionNucleo = _direccionNucleo;
    }

    // Registrar evento: permitido solo desde el núcleo o módulos enlazados
    function registrarEvento(address origen, string calldata tipoEvento, string calldata descripcion) external soloNucleoOModuloEnlazado {
        emit EventoAuditoria(origen, tipoEvento, descripcion, block.timestamp);
    }

    // Permitir actualizar la dirección del núcleo (solo desde el núcleo actual)
    function actualizarDireccionNucleo(address _nuevaDireccion) external {
        require(msg.sender == direccionNucleo, "Solo el nucleo actual puede actualizar su direccion");
        direccionNucleo = _nuevaDireccion;
    }
}

/* ------------------------------------------------------------------
   CONTRATO: Inventario
   - Gestiona productos y stock
   - Solo el núcleo (o quien el núcleo autorice) realiza acciones privilegiadas
   ------------------------------------------------------------------ */
contract Inventario {
    address public direccionNucleo; // dirección del NucleoCadena

    struct Producto {
        string nombre;
        uint256 stock;
        bool activo;
    }

    mapping(uint256 => Producto) public productos;

    event ProductoRegistrado(uint256 indexed productoId, string nombre, uint256 cantidad);
    event StockActualizado(uint256 indexed productoId, uint256 nuevoStock);

    modifier soloNucleo() {
        require(msg.sender == direccionNucleo, "Solo el nucleo puede ejecutar ciertas acciones");
        _;
    }

    constructor(address _direccionNucleo) {
        require(_direccionNucleo != address(0), "Direccion nucleo invalida");
        direccionNucleo = _direccionNucleo;
    }

    // Registrar producto (lo ejecuta el núcleo)
    function registrarProducto(uint256 productoId, string calldata nombre, uint256 cantidadInicial) external soloNucleo {
        require(!productos[productoId].activo, "Producto ya existe");
        productos[productoId] = Producto({nombre: nombre, stock: cantidadInicial, activo: true});
        emit ProductoRegistrado(productoId, nombre, cantidadInicial);
    }

    // Consultar existencia
    function existeProducto(uint256 productoId) external view returns (bool) {
        return productos[productoId].activo;
    }

    // Obtener stock
    function obtenerStock(uint256 productoId) external view returns (uint256) {
        require(productos[productoId].activo, "Producto no existe");
        return productos[productoId].stock;
    }

    // Aumentar stock (ej: producción finalizada)
    function aumentarStock(uint256 productoId, uint256 cantidad) external soloNucleo {
        require(productos[productoId].activo, "Producto no existe");
        productos[productoId].stock += cantidad;
        emit StockActualizado(productoId, productos[productoId].stock);
    }

    // Reducir stock (ej: crear envío)
    function reducirStock(uint256 productoId, uint256 cantidad) external soloNucleo {
        require(productos[productoId].activo, "Producto no existe");
        require(productos[productoId].stock >= cantidad, "Stock insuficiente");
        productos[productoId].stock -= cantidad;
        emit StockActualizado(productoId, productos[productoId].stock);
    }

    // Actualizar dirección del núcleo (solo núcleo puede solicitarlo)
    function actualizarDireccionNucleo(address _nuevaDireccion) external soloNucleo {
        direccionNucleo = _nuevaDireccion;
    }
}

/* ------------------------------------------------------------------
   CONTRATO: Produccion
   - Crea y finaliza órdenes de producción
   - Consume insumos llamando a Inventario vía núcleo
   ------------------------------------------------------------------ */
contract Produccion {
    address public direccionNucleo;
    uint256 public siguienteOrdenId;

    struct OrdenProduccion {
        uint256 ordenId;
        uint256 productoId;
        uint256 cantidad;
        address responsable;
        bool finalizada;
    }

    mapping(uint256 => OrdenProduccion) public ordenes;

    event OrdenCreada(uint256 indexed ordenId, uint256 productoId, uint256 cantidad, address responsable);
    event OrdenFinalizada(uint256 indexed ordenId, uint256 productoId, uint256 cantidad);

    modifier soloNucleo() {
        require(msg.sender == direccionNucleo, "Solo el nucleo puede ejecutar ciertas acciones");
        _;
    }

    constructor(address _direccionNucleo) {
        require(_direccionNucleo != address(0), "Direccion nucleo invalida");
        direccionNucleo = _direccionNucleo;
        siguienteOrdenId = 1;
    }

    // Crear orden (invocado por núcleo)
    function crearOrdenProduccion(uint256 productoId, uint256 cantidad, address responsable) external soloNucleo returns (uint256) {
        uint256 ordenId = siguienteOrdenId++;
        ordenes[ordenId] = OrdenProduccion({
            ordenId: ordenId,
            productoId: productoId,
            cantidad: cantidad,
            responsable: responsable,
            finalizada: false
        });
        emit OrdenCreada(ordenId, productoId, cantidad, responsable);
        return ordenId;
    }

    // Consumir insumos: reduce stock del inventario (vía núcleo)
    function consumirInsumos(uint256 productoId, uint256 cantidad) external soloNucleo {
        address direccionInventario = NucleoCadena(direccionNucleo).direccionInventario();
        require(direccionInventario != address(0), "Inventario no enlazado");
        IInventario(direccionInventario).reducirStock(productoId, cantidad);

        // Registrar en auditoría si existe
        address direccionAuditoria = NucleoCadena(direccionNucleo).direccionAuditoria();
        if (direccionAuditoria != address(0)) {
            Auditoria(direccionAuditoria).registrarEvento(address(this), "consumoInsumos", _concatStrUint("Consumo productoId:", productoId, cantidad));
        }
    }

    // Finalizar producción: aumenta stock en inventario
    function finalizarProduccion(uint256 ordenId) external soloNucleo {
        OrdenProduccion storage ord = ordenes[ordenId];
        require(ord.ordenId != 0, "Orden no existe");
        require(!ord.finalizada, "Orden ya finalizada");
        ord.finalizada = true;

        address direccionInventario = NucleoCadena(direccionNucleo).direccionInventario();
        require(direccionInventario != address(0), "Inventario no enlazado");
        IInventario(direccionInventario).aumentarStock(ord.productoId, ord.cantidad);

        emit OrdenFinalizada(ordenId, ord.productoId, ord.cantidad);

        // Registrar en auditoría
        address direccionAuditoria = NucleoCadena(direccionNucleo).direccionAuditoria();
        if (direccionAuditoria != address(0)) {
            Auditoria(direccionAuditoria).registrarEvento(address(this), "finalizarProduccion", _concatStrUint("OrdenFinalizada:", ordenId, ord.cantidad));
        }
    }

    // Helpers
    function _concatStrUint(string memory texto, uint256 numero1, uint256 numero2) internal pure returns (string memory) {
        return string(abi.encodePacked(texto, " ", _uintToString(numero1), " cantidad:", _uintToString(numero2)));
    }

    function _uintToString(uint256 v) internal pure returns (string memory) {
        if (v == 0) { return "0"; }
        uint256 j = v; uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (v != 0) {
            k = k - 1;
            bstr[k] = bytes1(uint8(48 + v % 10));
            v /= 10;
        }
        return string(bstr);
    }

    // Actualizar direccion del nucleo (invocado por nucleo)
    function actualizarDireccionNucleo(address _nuevaDireccion) external soloNucleo {
        direccionNucleo = _nuevaDireccion;
    }
}

/* ------------------------------------------------------------------
   CONTRATO: Logistica
   - Maneja envíos, asigna transportistas y marca entregas
   - Al marcar entregado, notifica a Pagos para procesar cobro
   ------------------------------------------------------------------ */
contract Logistica {
    address public direccionNucleo;
    uint256 public siguienteEnvioId;

    enum EstadoEnvio { Creado, EnTransito, Entregado, Cancelado }

    struct Envio {
        uint256 envioId;
        uint256 productoId;
        uint256 cantidad;
        string destino;
        address transportista;
        EstadoEnvio estado;
    }

    mapping(uint256 => Envio) public envios;

    event EnvioCreado(uint256 indexed envioId, uint256 productoId, uint256 cantidad, string destino);
    event TransportistaAsignado(uint256 indexed envioId, address transportista);
    event EnvioEntregado(uint256 indexed envioId);

    modifier soloNucleo() {
        require(msg.sender == direccionNucleo, "Solo el nucleo puede ejecutar ciertas acciones");
        _;
    }

    constructor(address _direccionNucleo) {
        require(_direccionNucleo != address(0), "Direccion nucleo invalida");
        direccionNucleo = _direccionNucleo;
        siguienteEnvioId = 1;
    }

    // Crear envío: verifica stock y reduce (reserva)
    function crearEnvio(uint256 productoId, uint256 cantidad, string calldata destino) external soloNucleo returns (uint256) {
        address direccionInventario = NucleoCadena(direccionNucleo).direccionInventario();
        require(direccionInventario != address(0), "Inventario no enlazado");
        uint256 stock = IInventario(direccionInventario).obtenerStock(productoId);
        require(stock >= cantidad, "Stock insuficiente para envio");

        // Reducir stock (reserva)
        IInventario(direccionInventario).reducirStock(productoId, cantidad);

        uint256 envioId = siguienteEnvioId++;
        envios[envioId] = Envio({
            envioId: envioId,
            productoId: productoId,
            cantidad: cantidad,
            destino: destino,
            transportista: address(0),
            estado: EstadoEnvio.Creado
        });

        emit EnvioCreado(envioId, productoId, cantidad, destino);

        // Auditoría
        address direccionAuditoria = NucleoCadena(direccionNucleo).direccionAuditoria();
        if (direccionAuditoria != address(0)) {
            Auditoria(direccionAuditoria).registrarEvento(address(this), "crearEnvio", _concatStrUint("EnvioId:", envioId, cantidad));
        }

        return envioId;
    }

    // Asignar transportista
    function asignarTransportista(uint256 envioId, address transportista) external soloNucleo {
        Envio storage e = envios[envioId];
        require(e.envioId != 0, "Envio no existe");
        e.transportista = transportista;
        e.estado = EstadoEnvio.EnTransito;
        emit TransportistaAsignado(envioId, transportista);
    }

    // Marcar entregado y notificar a Pagos
    function marcarEntregado(uint256 envioId) external soloNucleo {
        Envio storage e = envios[envioId];
        require(e.envioId != 0, "Envio no existe");
        require(e.estado == EstadoEnvio.EnTransito || e.estado == EstadoEnvio.Creado, "Estado invalido");
        e.estado = EstadoEnvio.Entregado;
        emit EnvioEntregado(envioId);

        // Notificar a Pagos
        address direccionPagos = NucleoCadena(direccionNucleo).direccionPagos();
        if (direccionPagos != address(0)) {
            Pagos(direccionPagos).registrarCobroPorEnvio(envioId, e.productoId, e.cantidad, e.destino);
        }

        // Auditoría
        address direccionAuditoria = NucleoCadena(direccionNucleo).direccionAuditoria();
        if (direccionAuditoria != address(0)) {
            Auditoria(direccionAuditoria).registrarEvento(address(this), "marcarEntregado", _concatStrUint("EnvioId:", envioId, e.cantidad));
        }
    }

    // Consultar estado
    function consultarEstadoEnvio(uint256 envioId) external view returns (EstadoEnvio) {
        require(envios[envioId].envioId != 0, "Envio no existe");
        return envios[envioId].estado;
    }

    // Helpers
    function _concatStrUint(string memory texto, uint256 numero1, uint256 numero2) internal pure returns (string memory) {
        return string(abi.encodePacked(texto, " ", _uintToString(numero1), " cantidad:", _uintToString(numero2)));
    }

    function _uintToString(uint256 v) internal pure returns (string memory) {
        if (v == 0) { return "0"; }
        uint256 j = v; uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (v != 0) {
            k = k - 1;
            bstr[k] = bytes1(uint8(48 + v % 10));
            v /= 10;
        }
        return string(bstr);
    }

    // Actualizar direccion del nucleo
    function actualizarDireccionNucleo(address _nuevaDireccion) external soloNucleo {
        direccionNucleo = _nuevaDireccion;
    }
}

/* ------------------------------------------------------------------
   CONTRATO: Pagos
   - Registra pagos y cobros (modelo simplificado)
   - Solo acepta notificaciones desde Logistica enlazada
   ------------------------------------------------------------------ */
contract Pagos {
    address public direccionNucleo;
    mapping(address => uint256) public balanceProveedores;
    mapping(address => uint256) public balanceClientes;

    event PagoRegistradoProveedor(address indexed proveedor, uint256 monto);
    event CobroRegistradoCliente(address indexed cliente, uint256 monto);
    event CobroPorEnvio(uint256 indexed envioId, uint256 productoId, uint256 cantidad, string destino);

    modifier soloNucleo() {
        require(msg.sender == direccionNucleo, "Solo el nucleo puede ejecutar ciertas acciones");
        _;
    }

    constructor(address _direccionNucleo) {
        require(_direccionNucleo != address(0), "Direccion nucleo invalida");
        direccionNucleo = _direccionNucleo;
    }

    // Registrar pago a proveedor (invocado por nucleo)
    function registrarPagoProveedor(address proveedor, uint256 monto) external soloNucleo {
        balanceProveedores[proveedor] += monto;
        emit PagoRegistradoProveedor(proveedor, monto);

        // Auditoría
        address direccionAuditoria = NucleoCadena(direccionNucleo).direccionAuditoria();
        if (direccionAuditoria != address(0)) {
            Auditoria(direccionAuditoria).registrarEvento(address(this), "pagoProveedor", _concatAddrUint(proveedor, monto));
        }
    }

    // Registrar cobro de cliente (invocado por nucleo)
    function registrarCobroCliente(address cliente, uint256 monto) external soloNucleo {
        balanceClientes[cliente] += monto;
        emit CobroRegistradoCliente(cliente, monto);

        // Auditoría
        address direccionAuditoria = NucleoCadena(direccionNucleo).direccionAuditoria();
        if (direccionAuditoria != address(0)) {
            Auditoria(direccionAuditoria).registrarEvento(address(this), "cobroCliente", _concatAddrUint(cliente, monto));
        }
    }

    // Función llamada por Logistica (la función verifica que el caller sea la Logistica enlazada)
    function registrarCobroPorEnvio(uint256 envioId, uint256 productoId, uint256 cantidad, string calldata destino) external {
        address direccionLogistica = NucleoCadena(direccionNucleo).direccionLogistica();
        require(msg.sender == direccionLogistica, "Solo la logistica enlazada puede llamar esta funcion");
        emit CobroPorEnvio(envioId, productoId, cantidad, destino);

        // Auditoría
        address direccionAuditoria = NucleoCadena(direccionNucleo).direccionAuditoria();
        if (direccionAuditoria != address(0)) {
            Auditoria(direccionAuditoria).registrarEvento(address(this), "cobroPorEnvio", _concatStrUint("EnvioId:", envioId, cantidad));
        }
    }

    // Helpers
    function _concatAddrUint(address addr, uint256 numero) internal pure returns (string memory) {
        return string(abi.encodePacked(_addressToString(addr), " monto:", _uintToString(numero)));
    }

    function _concatStrUint(string memory texto, uint256 numero1, uint256 numero2) internal pure returns (string memory) {
        return string(abi.encodePacked(texto, " ", _uintToString(numero1), " cantidad:", _uintToString(numero2)));
    }

    function _addressToString(address _addr) internal pure returns (string memory) {
        bytes32 value = bytes32(uint256(uint160(_addr)));
        bytes16 hexAlphabet = "0123456789abcdef";
        bytes memory str = new bytes(42);
        str[0] = '0';
        str[1] = 'x';
        for (uint i = 0; i < 20; i++) {
            str[2 + i * 2] = hexAlphabet[uint8(value[i + 12] >> 4)];
            str[3 + i * 2] = hexAlphabet[uint8(value[i + 12] & 0x0f)];
        }
        return string(str);
    }

    function _uintToString(uint256 v) internal pure returns (string memory) {
        if (v == 0) { return "0"; }
        uint256 j = v; uint256 len;
        while (j != 0) { len++; j /= 10; }
        bytes memory bstr = new bytes(len);
        uint256 k = len;
        while (v != 0) {
            k = k - 1;
            bstr[k] = bytes1(uint8(48 + v % 10));
            v /= 10;
        }
        return string(bstr);
    }

    // Actualizar direccion del nucleo (invocado por nucleo)
    function actualizarDireccionNucleo(address _nuevaDireccion) external soloNucleo {
        direccionNucleo = _nuevaDireccion;
    }
}
