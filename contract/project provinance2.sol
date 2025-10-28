// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

/**
 * @title RecycledMaterialProvenance
 * @dev Smart contract for tracking recycled materials through their lifecycle
 * Optimized to avoid stack too deep errors
 */
contract RecycledMaterialProvenance {
    
    // Material stages in the recycling lifecycle
    enum Stage { Collected, Processed, Manufactured, Retail }
    
    // Material types
    enum MaterialType { Plastic, Metal, Electronics, Glass, Paper }
    
    // Structure for material batch
    struct MaterialBatch {
        uint256 batchId;
        MaterialType materialType;
        uint256 weight;
        uint256 purityLevel;
        Stage currentStage;
        address collectorAddress;
        address processorAddress;
        address manufacturerAddress;
        uint256 collectionTimestamp;
        string collectionLocation;
        bool isVerified;
    }
    
    // Structure for final products
    struct RecycledProduct {
        uint256 productId;
        string productName;
        uint256 recycledContentPercentage;
        address manufacturer;
        uint256 manufacturingDate;
        bool isActive;
    }
    
    // Mappings
    mapping(uint256 => MaterialBatch) public materialBatches;
    mapping(uint256 => RecycledProduct) public recycledProducts;
    mapping(uint256 => uint256[]) public productBatches; // productId => batchIds
    mapping(address => bool) public authorizedCollectors;
    mapping(address => bool) public authorizedProcessors;
    mapping(address => bool) public authorizedManufacturers;
    
    // Counters
    uint256 public batchCounter;
    uint256 public productCounter;
    
    // Contract owner
    address public owner;
    
    // Events
    event MaterialCollected(uint256 indexed batchId, MaterialType materialType, uint256 weight);
    event MaterialProcessed(uint256 indexed batchId, uint256 purityLevel);
    event ProductManufactured(uint256 indexed productId, string productName, uint256 recycledPercentage);
    event EntityAuthorized(address indexed entity, string role);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyCollector() {
        require(authorizedCollectors[msg.sender], "Not collector");
        _;
    }
    
    modifier onlyProcessor() {
        require(authorizedProcessors[msg.sender], "Not processor");
        _;
    }
    
    modifier onlyManufacturer() {
        require(authorizedManufacturers[msg.sender], "Not manufacturer");
        _;
    }
    
    constructor() {
        owner = msg.sender;
    }
    
    /**
     * @dev Authorize collectors
     */
    function authorizeCollector(address _entity) public onlyOwner {
        authorizedCollectors[_entity] = true;
        emit EntityAuthorized(_entity, "collector");
    }
    
    /**
     * @dev Authorize processors
     */
    function authorizeProcessor(address _entity) public onlyOwner {
        authorizedProcessors[_entity] = true;
        emit EntityAuthorized(_entity, "processor");
    }
    
    /**
     * @dev Authorize manufacturers
     */
    function authorizeManufacturer(address _entity) public onlyOwner {
        authorizedManufacturers[_entity] = true;
        emit EntityAuthorized(_entity, "manufacturer");
    }
    
    /**
     * @dev Register collected recycled material
     * Core Function 1: Material Collection Registration
     */
    function registerMaterialCollection(
        MaterialType _materialType,
        uint256 _weight,
        string memory _location
    ) public onlyCollector returns (uint256) {
        batchCounter++;
        
        materialBatches[batchCounter] = MaterialBatch({
            batchId: batchCounter,
            materialType: _materialType,
            weight: _weight,
            purityLevel: 0,
            currentStage: Stage.Collected,
            collectorAddress: msg.sender,
            processorAddress: address(0),
            manufacturerAddress: address(0),
            collectionTimestamp: block.timestamp,
            collectionLocation: _location,
            isVerified: false
        });
        
        emit MaterialCollected(batchCounter, _materialType, _weight);
        return batchCounter;
    }
    
    /**
     * @dev Process and verify material purity
     * Core Function 2: Material Processing & Verification
     */
    function processMaterial(
        uint256 _batchId,
        uint256 _purityLevel
    ) public onlyProcessor {
        MaterialBatch storage batch = materialBatches[_batchId];
        
        require(batch.batchId != 0, "Batch not found");
        require(batch.currentStage == Stage.Collected, "Wrong stage");
        require(_purityLevel <= 100, "Invalid purity");
        
        batch.purityLevel = _purityLevel;
        batch.processorAddress = msg.sender;
        batch.currentStage = Stage.Processed;
        batch.isVerified = true;
        
        emit MaterialProcessed(_batchId, _purityLevel);
    }
    
    /**
     * @dev Create final product with recycled materials
     * Core Function 3: Product Manufacturing with Traceability
     */
    function createRecycledProduct(
        string memory _productName,
        uint256[] memory _batchIds,
        uint256 _recycledPercentage
    ) public onlyManufacturer returns (uint256) {
        require(_recycledPercentage <= 100, "Invalid percentage");
        require(_batchIds.length > 0, "No batches");
        
        // Verify batches
        for (uint256 i = 0; i < _batchIds.length; i++) {
            MaterialBatch storage b = materialBatches[_batchIds[i]];
            require(b.isVerified, "Not verified");
            require(b.currentStage == Stage.Processed, "Not processed");
            
            b.currentStage = Stage.Manufactured;
            b.manufacturerAddress = msg.sender;
        }
        
        productCounter++;
        
        recycledProducts[productCounter] = RecycledProduct({
            productId: productCounter,
            productName: _productName,
            recycledContentPercentage: _recycledPercentage,
            manufacturer: msg.sender,
            manufacturingDate: block.timestamp,
            isActive: true
        });
        
        productBatches[productCounter] = _batchIds;
        
        emit ProductManufactured(productCounter, _productName, _recycledPercentage);
        return productCounter;
    }
    
    /**
     * @dev Get product information
     */
    function getProductInfo(uint256 _productId) public view returns (
        string memory productName,
        uint256 recycledPercentage,
        address manufacturer,
        uint256 manufacturingDate
    ) {
        RecycledProduct storage p = recycledProducts[_productId];
        require(p.productId != 0, "Product not found");
        
        return (p.productName, p.recycledContentPercentage, p.manufacturer, p.manufacturingDate);
    }
    
    /**
     * @dev Get batch IDs used in a product
     */
    function getProductBatches(uint256 _productId) public view returns (uint256[] memory) {
        require(recycledProducts[_productId].productId != 0, "Product not found");
        return productBatches[_productId];
    }
    
    /**
     * @dev Get batch basic info
     */
    function getBatchInfo(uint256 _batchId) public view returns (
        MaterialType materialType,
        uint256 weight,
        uint256 purityLevel,
        Stage currentStage,
        bool isVerified
    ) {
        MaterialBatch storage b = materialBatches[_batchId];
        require(b.batchId != 0, "Batch not found");
        
        return (b.materialType, b.weight, b.purityLevel, b.currentStage, b.isVerified);
    }
    
    /**
     * @dev Get batch addresses
     */
    function getBatchAddresses(uint256 _batchId) public view returns (
        address collector,
        address processor,
        address manufacturer
    ) {
        MaterialBatch storage b = materialBatches[_batchId];
        require(b.batchId != 0, "Batch not found");
        
        return (b.collectorAddress, b.processorAddress, b.manufacturerAddress);
    }
    
    /**
     * @dev Get batch location and timestamp
     */
    function getBatchDetails(uint256 _batchId) public view returns (
        string memory location,
        uint256 timestamp
    ) {
        MaterialBatch storage b = materialBatches[_batchId];
        require(b.batchId != 0, "Batch not found");
        
        return (b.collectionLocation, b.collectionTimestamp);
    }
}
