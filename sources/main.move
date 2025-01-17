module saloon::saloon {
use std::string::{String};
use sui::coin::{Coin,split, put,take};
use sui::balance::{Balance,zero};
use sui::table::{Self, Table};
// use std::option::{none,some};
use sui::tx_context::{sender};
use sui::sui::SUI;
use sui::event;

//define errors codes
const EONLYOWNER:u64=0;
const SERVICEDOESNOTEXISTS:u64=1;
const INVALIDRATING:u64=2;
const INSUFFICIENTBALANCE:u64=3;

public struct Saloon has key, store {
    id: UID,
    saloonid:ID,
    name: String,   
    location: String,
    saloon_url: String,
    balance:Balance<SUI>,
    services: vector<ServicesRendered>,
    rates:vector<Rate>,
    review: Table<address,CustomerReview >
}

public struct ServicesRendered has store, drop {
    id:u64,
    servicename: String,
    servicedescription: String,
    amount: u64
}

public struct Rate has store,key{
    id:UID,
    rate:u64,
    by:address
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

  /// Customer Review struct
public struct CustomerReview has store, copy, drop {
    // by:address,
    comments: String,     // Customer comments
}

// struct for price update 
public struct PriceUpdated has copy,drop{
    name:String,
    new_amount:u64
}

// struct for description update 
public struct DescriptionUpdated has copy,drop{
    name:String,
    new_description:String
}

// struct for adding rate update
public struct RateAdded has copy,drop{
    by:address,
    rating:u64
}


public struct WithdrawAmount has copy,drop{
      amount:u64,
      recipient:address
}

public  struct Receipt has key, store {
    id:UID,
    service_id: u64,
    amount_paid: u64,
    user: address,
    }


// create saloon
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
        services:vector::empty(),
        rates:vector::empty(),
        review: table::new(ctx)
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

//function that add service to a saloon
public entry fun add_service_to_saloon(saloon:&mut Saloon,servicename:String,servicedescription:String,amount:u64,owner:&AdminCap){

    //verify that its only the admin can add service
    assert!(&owner.saloonid == object::uid_as_inner(&saloon.id),EONLYOWNER);
    let id:u64=saloon.services.length();
    //create a new service
    let service=ServicesRendered{
        id,
        servicename,
        servicedescription,
        amount,
    };
    saloon.services.push_back(service);

     event::emit(ServiceAdded{
        name:servicename,
        id
    });

}


// update the price 
public entry fun update_services_price(saloon:&mut Saloon,saloonid:u64, new_amount:u64,owner:&AdminCap){

    //check that its the owner performing the action
    assert!(&owner.saloonid == object::uid_as_inner(&saloon.id),EONLYOWNER);

     //check if service exisy
    assert!(saloonid<=saloon.services.length(),SERVICEDOESNOTEXISTS);

    saloon.services[saloonid].amount=new_amount;

     event::emit(PriceUpdated{
        name:saloon.services[saloonid].servicename,
        new_amount
    });
}

//update price
public entry fun update_services_description(saloon:&mut Saloon,saloonid:u64,new_description:String,owner:&AdminCap){

    //check that its the owner performing the action
    assert!(&owner.saloonid == object::uid_as_inner(&saloon.id),EONLYOWNER);

     //check that sevice exists
    assert!(saloonid<=saloon.services.length(),SERVICEDOESNOTEXISTS);

    saloon.services[saloonid].servicedescription=new_description;

     event::emit(DescriptionUpdated{
        name:saloon.services[saloonid].servicename,
        new_description
        
    });
}



//function to rate a saloon
public entry fun rate_saloon(saloon:&mut Saloon,rating:u64,ctx:&mut TxContext){

    //check if rate is greater than zero and is less than 6
       assert!(rating >0 && rating < 6,INVALIDRATING);

      //rate
      let newrate=Rate{
        id:object::new(ctx),
        rate:rating,
        by:tx_context::sender(ctx)
      };
      //update vector rates
      saloon.rates.push_back(newrate);

      //emit event
      event::emit(RateAdded{
        by:tx_context::sender(ctx),
        rating
      });
  }



//function to comment on a saloon
public entry fun comment_on_saloon(self: &mut Saloon, comments_: String, ctx: &mut TxContext) {
    let review = CustomerReview {
            comments: comments_
    };
        table::add(&mut self.review, sender(ctx), review);
}

// pay for service
public entry fun pay_for_service(saloon:&mut Saloon,serviceid:u64,amount:&mut Coin<SUI>,ctx:&mut TxContext){

        let mut index:u64=0;
        let user = tx_context::sender(ctx);
        let serviceslength:u64=saloon.services.length();

        while(index < serviceslength){
        let service=&saloon.services[index];
        if(service.id==serviceid){

    //verify the user has sufficient amount to perform the transaction
    assert!(amount.value()>=saloon.services[index].amount,INSUFFICIENTBALANCE);

        let payamount=saloon.services[index].amount;

        let pay=amount.split(payamount,ctx);
         
        put(&mut saloon.balance, pay);

        // Generate a receipt
        let receipt = Receipt {
            id:object::new(ctx),
            service_id: serviceid,
            amount_paid: payamount,
            user,
    };
        // Transfer the receipt to the user
        transfer::public_transfer(receipt, user);
         return
     };
            index=index+1;
     };
        abort 0
}

// get saloon info 
public fun view_services_info(saloon: &Saloon, saloonid: u64) : (u64, String, String, u64) {

 //check if service is available
   assert!(saloonid <= saloon.services.length(),SERVICEDOESNOTEXISTS);
    let service = &saloon.services[saloonid];
     (
        service.id,
        service.servicename,
        service.servicedescription,
        service.amount,

    )
}


// Get saloon balance
public fun get_saloon_balance(saloon: &Saloon): u64 {
        saloon.balance.value()  
    }

//owner withdraw amount
public entry fun withdraw_funds(
        owner: &AdminCap,      
        saloon: &mut Saloon,
        amount:u64,
        recipient:address,
        ctx: &mut TxContext,
    ) {

    //verify amount is sufficient
     assert!(amount > 0 && amount <= saloon.balance.value(), INSUFFICIENTBALANCE);

    //ensure its the owner performing the action
     assert!(&owner.saloonid==object::uid_as_inner(&saloon.id),EONLYOWNER);
     let takeamount = take(&mut saloon.balance, amount, ctx);
         transfer::public_transfer(takeamount, recipient);
       
        //emit event
         event::emit(WithdrawAmount{
            amount,
            recipient
        });
    }




































































































}
