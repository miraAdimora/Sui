module dacade_deepbook::saloon {
// use sui::object::{Self, UID, ID};
use std::string::{String};
// use sui::coin::{Coin,split, put,take};
use sui::balance::{Balance,zero};
// use std::option::{none,some};
use sui::sui::SUI;
use sui::event;

//define errors codes
const ONLYOWNER:u64=0;
const ITEMEDOESNOTEXISTS:u64=1;
// const MUSTBEREGISTERED:u64=2;
// const INSUFFICIENTBALANCE:u64=3;
// const ITEMALREADYSOLD:u64=4;
// const ITEMALREADYRENTED:u64=5;

public struct Saloon has key, store {
    id: UID,
    saloonid:ID,
    name: String,   
    location: String,
    saloon_url: String,
    balance:Balance<SUI>,
    saloons: vector<ServicesRendered>
}

public struct ServicesRendered has store, drop {
    id:u64,
    servicename: String,
    servicedescription: String,
    amount: u64
}

public struct AdminCap has key{
    id:UID, //Unique identifier for the admin
    saloonid:ID //The ID of the relief center associated with the admin
}

// Event struct when a farm item is added
public struct ServiceAdded has copy,drop{
    id:u64,
    name:String
}

// public struct ServiceUpdated has copy, drop {
//     name: String,
//     // servicedescription: String,
//     amount: u64,
// }
// struct for price update 
public struct ServiceUpdated has copy,drop{
    name:String,
    description:String,
    new_amount:u64
}



// create farm
public entry fun create_saloon( name: String, location: String, saloon_url: String,ctx: &mut TxContext ) {
    let id=object::new(ctx);
    let saloonid=object::uid_to_inner(&id);

        // Initialize a new farm object
    let saloon = Saloon {
        id,
        saloonid:saloonid,
        name,   
        location,
        saloon_url,
        balance:zero<SUI>(),
        saloons:vector::empty()
        };

  // Create the AdminCap associated with the farm
    let admin_cap = AdminCap {
        id: object::new(ctx),  // Generate a new UID for AdminCap
        saloonid,  // Associate the farm ID
        };

        // Transfer the admin capability to the sender
        transfer::transfer(admin_cap, tx_context::sender(ctx));
        
        transfer::share_object(saloon);
}

//add farm items to a farm
public entry fun add_service_to_saloon(saloon:&mut Saloon,servicename:String,servicedescription:String,amount:u64,owner:&AdminCap){

    //verify that its only the admin can add items
    assert!(&owner.saloonid == object::uid_as_inner(&saloon.id),ONLYOWNER);
    let id:u64=saloon.saloons.length();
    //create a new service
    let service=ServicesRendered{
        id,
        servicename,
        servicedescription,
        amount,
    };
    saloon.saloons.push_back(service);

     event::emit(ServiceAdded{
        name:servicename,
        id
    });

}


// update the price of an item in a farm
public entry fun update_services(saloon:&mut Saloon,saloonid:u64,new_name: String,new_description:String, new_amount:u64,owner:&AdminCap){

    //check that its the owner performing the action
    assert!(&owner.saloonid == object::uid_as_inner(&saloon.id),ONLYOWNER);

     //check that item exists
    assert!(saloonid<=saloon.saloons.length(),ITEMEDOESNOTEXISTS);

    saloon.saloons[saloonid].servicename=new_name;
    saloon.saloons[saloonid].servicedescription=new_description;
    saloon.saloons[saloonid].amount=new_amount;

     event::emit(ServiceUpdated{
        name:saloon.saloons[saloonid].servicename,
        description:saloon.saloons[saloonid].servicedescription,
        new_amount
    });
}







































































































}
