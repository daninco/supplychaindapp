pragma solidity >=0.4.21 <0.6.0;

contract supplyChain {
    uint32 public product_id = 0;   // Product ID. unit32 used as these are going on the blockchain so need to be mindful of size.
    uint32 public participant_id = 0;   // Participant ID
    uint32 public owner_id = 0;   // Ownership ID

    struct product { // a collection of variables or values
        string modelNumber;
        string partNumber;
        string serialNumber;
        address productOwner;
        uint32 cost;
        uint32 mfgTimeStamp;
    }

    mapping(uint32 => product) public products; //Maps one element to another. Creating an indexed list of product structures called products, listed by product ID

    struct participant {
        string userName;
        string password;
        string participantType; // eg 'Manufacturere'
        address participantAddress; //maps to an ethereum address
    }
    mapping(uint32 => participant) public participants; //creates list of participants

    struct ownership {
        uint32 productId;
        uint32 ownerId;
        uint32 trxTimeStamp;
        address productOwner; //owner linked to owner address
    }
    mapping(uint32 => ownership) public ownerships; // ownerships by ownership ID (owner_id)
    mapping(uint32 => uint32[]) public productTrack;  // ownerships by Product ID (product_id) / Movement track for a product
    //using two mappings allows better viewing of provenance

    event TransferOwnership(uint32 productId);

    // memory means not stored on blockchain 
    function addParticipant(string memory _name, string memory _pass, address _pAdd, string memory _pType) public returns (uint32){
        uint32 userId = participant_id++; //inrementing the global (stored on blockchain) participant_id
        participants[userId].userName = _name; //this format relateso to the strucutre created earlier.
        participants[userId].password = _pass; // so this sections is assigning the attributes inputted to the function to the related part of the structure
        participants[userId].participantAddress = _pAdd;
        participants[userId].participantType = _pType;

        return userId; // this in turn all producecs a user ID number
    }

    //returns all the participant information
    function getParticipant(uint32 _participant_id) public view returns (string memory,address,string memory) {
        return (participants[_participant_id].userName,
                participants[_participant_id].participantAddress,
                participants[_participant_id].participantType);
    }

    //same as above but for products. BUT Currently this only allows manufacturers to add items to the data base.
    //solidity cant compare stings, it can only compare hashes of strings
    // most common hashing method is keccak256 
    function addProduct(uint32 _ownerId,
                        string memory _modelNumber,
                        string memory _partNumber,
                        string memory _serialNumber,
                        uint32 _productCost) public returns (uint32) {
        if(keccak256(abi.encodePacked(participants[_ownerId].participantType)) == keccak256("Manufacturer")) {
            uint32 productId = product_id++; //abi.encodePacked(arg) turns the arg into a format ready for keccak256

            products[productId].modelNumber = _modelNumber;
            products[productId].partNumber = _partNumber;
            products[productId].serialNumber = _serialNumber;
            products[productId].cost = _productCost;
            products[productId].productOwner = participants[_ownerId].participantAddress;
            products[productId].mfgTimeStamp = uint32(now);

            return productId;
        } // this could be done using a require statement, potentially leading to less gas use

       return 0;
    }

    //a modifier used in newOwner function below.
    // Acts like a function. It ensures only the owner can assign a new owner.
    // i.e. no one can grab a product from the existing owner. 
    // msg.sender is the current owner address, so code checks the IDs match the current owner
    modifier onlyOwner(uint32 _productId) {
         require(msg.sender == products[_productId].productOwner,"");
         _;  //_; needed for running code after modifier is called

    }

    function getProduct(uint32 _productId) public view returns (string memory,string memory,string memory,uint32,address,uint32){
        return (products[_productId].modelNumber,
                products[_productId].partNumber,
                products[_productId].serialNumber,
                products[_productId].cost,
                products[_productId].productOwner,
                products[_productId].mfgTimeStamp);
    }

    //assigns a new owner. Applies functionality of moving items along supply chain.
    function newOwner(uint32 _user1Id,uint32 _user2Id, uint32 _prodId) onlyOwner(_prodId) public returns (bool) {
        participant memory p1 = participants[_user1Id]; // local structures to avoid gas charges
        participant memory p2 = participants[_user2Id]; 
        uint32 ownership_id = owner_id++; 

        //This goes through the cases of different transfers
        // Manufacturer --> supplier
        //Supplier --> supplier
        //supplier --> consumer
        if(keccak256(abi.encodePacked(p1.participantType)) == keccak256("Manufacturer")
            && keccak256(abi.encodePacked(p2.participantType))==keccak256("Supplier")){
            ownerships[ownership_id].productId = _prodId;
            ownerships[ownership_id].productOwner = p2.participantAddress;
            ownerships[ownership_id].ownerId = _user2Id;
            ownerships[ownership_id].trxTimeStamp = uint32(now);
            products[_prodId].productOwner = p2.participantAddress;
            productTrack[_prodId].push(ownership_id); // push means added to end
            emit TransferOwnership(_prodId); 
            //This has altered the ownership structure and aligned everything else accordingly
            // Technically, this is creating a new record, as the previous owner strucutre is logged on the blockchain

            return (true);
        }
        else if(keccak256(abi.encodePacked(p1.participantType)) == keccak256("Supplier") && keccak256(abi.encodePacked(p2.participantType))==keccak256("Supplier")){
            ownerships[ownership_id].productId = _prodId;
            ownerships[ownership_id].productOwner = p2.participantAddress;
            ownerships[ownership_id].ownerId = _user2Id;
            ownerships[ownership_id].trxTimeStamp = uint32(now);
            products[_prodId].productOwner = p2.participantAddress;
            productTrack[_prodId].push(ownership_id);
            emit TransferOwnership(_prodId);

            return (true);
        }
        else if(keccak256(abi.encodePacked(p1.participantType)) == keccak256("Supplier") && keccak256(abi.encodePacked(p2.participantType))==keccak256("Consumer")){
            ownerships[ownership_id].productId = _prodId;
            ownerships[ownership_id].productOwner = p2.participantAddress;
            ownerships[ownership_id].ownerId = _user2Id;
            ownerships[ownership_id].trxTimeStamp = uint32(now);
            products[_prodId].productOwner = p2.participantAddress;
            productTrack[_prodId].push(ownership_id);
            emit TransferOwnership(_prodId);

            return (true);
        }

        return (false);
    }

   // returns product track of a product ID
   function getProvenance(uint32 _prodId) external view returns (uint32[] memory) {

       return productTrack[_prodId];
    }

    // returns current owner of a product by creating a local copy of an ownership stucture
    function getOwnership(uint32 _regId)  public view returns (uint32,uint32,address,uint32) {

        ownership memory r = ownerships[_regId];

         return (r.productId,r.ownerId,r.productOwner,r.trxTimeStamp);
    }


    //simple and not a very secure function. Checking details match up. Just a strucutre for an authenticate process. 
    function authenticateParticipant(uint32 _uid,
                                    string memory _uname,
                                    string memory _pass,
                                    string memory _utype) public view returns (bool){
        if(keccak256(abi.encodePacked(participants[_uid].participantType)) == keccak256(abi.encodePacked(_utype))) {
            if(keccak256(abi.encodePacked(participants[_uid].userName)) == keccak256(abi.encodePacked(_uname))) {
                if(keccak256(abi.encodePacked(participants[_uid].password)) == keccak256(abi.encodePacked(_pass))) {
                    return (true);
                }
            }
        }

        return (false);
    }
}