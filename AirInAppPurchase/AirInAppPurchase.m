/*
 
 Copyright (c) 2012, DIVIJ KUMAR
 All rights reserved.
 
 Redistribution and use in source and binary forms, with or without
 modification, are permitted provided that the following conditions are met: 
 
 1. Redistributions of source code must retain the above copyright notice, this
 list of conditions and the following disclaimer. 
 2. Redistributions in binary form must reproduce the above copyright notice,
 this list of conditions and the following disclaimer in the documentation
 and/or other materials provided with the distribution. 
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
 ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 
 The views and conclusions contained in the software and documentation are those
 of the authors and should not be interpreted as representing official policies, 
 either expressed or implied, of the FreeBSD Project.
 
 
 */

/*
 * AirInAppPurchase.m
 * AirInAppPurchase
 *
 * Created by 豆花 on 2014/7/28.
 * Copyright (c) 2014年 __MyCompanyName__. All rights reserved.
 */

#import "AirInAppPurchase.h"
#import "NSString+Base64.h"

FREContext _AirInAppPurchaseContext = nil;
void *AirInAppRefToSelf;

@implementation AirInAppPurchase

- (id) init
{
    _productsDic = [[NSMutableDictionary alloc] init];
    self = [super init];
    if (self)
    {
        AirInAppRefToSelf = self;
    }
    return self;
}

-(void)dealloc
{
    [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    AirInAppRefToSelf = nil;
    [_productsDic release];
    [super dealloc];
}

- (BOOL) canMakePayment
{
    return [SKPaymentQueue canMakePayments];
}

- (void) registerObserver
{
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "LOGGING", (uint8_t*) "registerObserver");
    [[SKPaymentQueue defaultQueue] addTransactionObserver:self];
}


//////////////////////////////////////////////////////////////////////////////////////
// PRODUCT INFO
//////////////////////////////////////////////////////////////////////////////////////

// get products info
- (void) sendRequest:(SKRequest*)request AndContext:(FREContext*)ctx
{
    request.delegate = self;
    [request start];
}

// on product info received
- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
    [numberFormatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
    [numberFormatter setNumberStyle:NSNumberFormatterCurrencyStyle];
    
    //NSMutableDictionary *dictionary = [[NSMutableDictionary alloc] init];
    NSMutableArray * array = [[NSMutableArray alloc] init];
    NSString *formattedString;
    
    for (SKProduct* product in [response products])
    {
        [numberFormatter setLocale:product.priceLocale];
        formattedString = [numberFormatter stringFromNumber:product.price];
        
        [_productsDic setValue:product forKey:product.productIdentifier];
        NSMutableDictionary* productDic = [[NSMutableDictionary alloc]init];
        [productDic setValue:product.localizedTitle forKey:@"title"];
        [productDic setValue:formattedString forKey:@"price"];
        [productDic setValue:product.productIdentifier forKey:@"id"];
        [productDic setValue:product.localizedDescription forKey:@"description"];
        [array addObject:productDic];
        //[dictionary setValue:productDic forKey:[product productIdentifier]];
    }
    
    
    NSString* jsonDictionary = [array JSONString];
    
    
    
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "LOGGING", (uint8_t*)[[NSString stringWithFormat:@"received productsRequest data: %@", jsonDictionary] UTF8String]);
    
    if ([response invalidProductIdentifiers] != nil && [[response invalidProductIdentifiers] count] > 0)
    {
        NSString* jsonArray = [[response invalidProductIdentifiers] JSONString];
        
        FREDispatchStatusEventAsync(_AirInAppPurchaseContext ,(uint8_t*) "PRODUCT_INFO_ERROR", (uint8_t*) [jsonArray UTF8String] );
    }
    else
    {
        FREDispatchStatusEventAsync(_AirInAppPurchaseContext ,(uint8_t*) "PRODUCT_INFO_RECEIVED", (uint8_t*) [jsonDictionary UTF8String] );
    }
}

// on product info finish
- (void)requestDidFinish:(SKRequest *)request
{
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext ,(uint8_t*) "DEBUG", (uint8_t*) [@"requestDidFinish" UTF8String] );
}

// on product info error
- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext ,(uint8_t*) "DEBUG", (uint8_t*) [@"requestDidFailWithError" UTF8String] );
}


//////////////////////////////////////////////////////////////////////////////////////
// PURCHASE PRODUCT
//////////////////////////////////////////////////////////////////////////////////////

// complete a transaction (item has been purchased, need to check the receipt)
- (void) completeTransaction:(SKPaymentTransaction*)transaction
{
    NSMutableDictionary *data;
    
    // purchase done
    // dispatch event
    data = [[NSMutableDictionary alloc] init];
    [data setValue:[[transaction payment] productIdentifier] forKey:@"id"];
    
    NSString* receiptString = [[[NSString alloc] initWithData:transaction.transactionReceipt encoding:NSUTF8StringEncoding] autorelease];
    [data setValue:[receiptString Base64String] forKey:@"receipt"];
    //[data setValue:@"AppStore"   forKey:@"receiptType"];
    
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"PURCHASE_SUCCESSFUL", (uint8_t*)[[data JSONString] UTF8String]);
}

// transaction failed, remove the transaction from the queue.
- (void) failedTransaction:(SKPaymentTransaction*)transaction
{
    // purchase failed
    NSMutableDictionary *data;
    
    [[transaction payment] productIdentifier];
    [[transaction error] code];
    
    data = [[NSMutableDictionary alloc] init];
    [data setValue:[NSNumber numberWithInteger:[[transaction error] code]]  forKey:@"code"];
    [data setValue:[[transaction error] localizedFailureReason] forKey:@"FailureReason"];
    [data setValue:[[transaction error] localizedDescription] forKey:@"FailureDescription"];
    [data setValue:[[transaction error] localizedRecoverySuggestion] forKey:@"RecoverySuggestion"];
    
    NSString *error = [data JSONString];//transaction.error.code == SKErrorPaymentCancelled ? @"RESULT_USER_CANCELED" : [data JSONString];
    
    // conclude the transaction
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
    
    // dispatch event
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"PURCHASE_ERROR", (uint8_t*) [error UTF8String]);
    
}

// transaction is being purchasing, logging the info.
- (void) purchasingTransaction:(SKPaymentTransaction*)transaction
{
    // purchasing transaction
    // dispatch event
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"PURCHASING", (uint8_t*)
                                [[[transaction payment] productIdentifier] UTF8String]
                                );
}

// transaction restored, remove the transaction from the queue.
- (void) restoreTransaction:(SKPaymentTransaction*)transaction
{
    // transaction restored
    // dispatch event
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"TRANSACTION_RESTORED", (uint8_t*)
                                [[[transaction error] localizedDescription] UTF8String]
                                );
    
    
    // conclude the transaction
    [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
}


// list of transactions has been updated.
- (void)paymentQueue:(SKPaymentQueue *)queue updatedTransactions:(NSArray *)transactions
{
    NSUInteger nbTransaction = [transactions count];
    NSString* pendingTransactionInformation = [NSString stringWithFormat:@"pending transaction - %@", [NSNumber numberWithUnsignedInteger:nbTransaction]];
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"UPDATED_TRANSACTIONS", (uint8_t*) [pendingTransactionInformation UTF8String]  );
    
    for ( SKPaymentTransaction* transaction in transactions)
    {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self completeTransaction:transaction];
                break;
            case SKPaymentTransactionStateFailed:
                [self failedTransaction:transaction];
                break;
            case SKPaymentTransactionStatePurchasing:
                [self purchasingTransaction:transaction];
                break;
            case SKPaymentTransactionStateRestored:
                [self restoreTransaction:transaction];
                break;
            default:
                FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"PURCHASE_UNKNOWN", (uint8_t*) [@"Unknown Reason" UTF8String]);
                break;
        }
    }
}

// restoring transaction is done.
- (void)paymentQueueRestoreCompletedTransactionsFinished:(SKPaymentQueue *)queue
{
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"restoreCompletedTransactions" UTF8String] );
}

// restoring transaction failed.
- (void)paymentQueue:(SKPaymentQueue *)queue restoreCompletedTransactionsFailedWithError:(NSError *)error
{
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"restoreFailed" UTF8String] );
}

// transaction has been removed.
- (void)paymentQueue:(SKPaymentQueue *)queue removedTransactions:(NSArray *)transactions
{
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"removeTransaction" UTF8String] );
}


@end


/* AirInAppPurchaseExtInitializer()
 * The extension initializer is called the first time the ActionScript side of the extension
 * calls ExtensionContext.createExtensionContext() for any context.
 *
 * Please note: this should be same as the <initializer> specified in the extension.xml 
 */
void AirInAppPurchaseExtInitializer(void** extDataToSet, FREContextInitializer* ctxInitializerToSet, FREContextFinalizer* ctxFinalizerToSet) 
{
    NSLog(@"Entering AirInAppPurchaseExtInitializer()");

    *extDataToSet = NULL;
    *ctxInitializerToSet = &AirInAppPurchaseContextInitializer;
    *ctxFinalizerToSet = &AirInAppPurchaseContextFinalizer;

    NSLog(@"Exiting AirInAppPurchaseExtInitializer()");
}

/* AirInAppPurchaseExtFinalizer()
 * The extension finalizer is called when the runtime unloads the extension. However, it may not always called.
 *
 * Please note: this should be same as the <finalizer> specified in the extension.xml 
 */
void AirInAppPurchaseExtFinalizer(void* extData) 
{
    NSLog(@"Entering AirInAppPurchaseExtFinalizer()");

    // Nothing to clean up.
    NSLog(@"Exiting AirInAppPurchaseExtFinalizer()");
    return;
}

/* ContextInitializer()
 * The context initializer is called when the runtime creates the extension context instance.
 */
void AirInAppPurchaseContextInitializer(void* extData, const uint8_t* ctxType, FREContext ctx, uint32_t* numFunctionsToTest, const FRENamedFunction** functionsToSet)
{
    NSLog(@"Entering ContextInitializer()");
    
    /* The following code describes the functions that are exposed by this native extension to the ActionScript code.
     */
    static FRENamedFunction func[] = 
    {
        MAP_FUNCTION(isInAppPurchaseSupported, NULL),
        MAP_FUNCTION(AirInAppPurchaseInit, NULL),
        MAP_FUNCTION(makePurchase, NULL),
        MAP_FUNCTION(userCanMakeAPurchase, NULL),
        MAP_FUNCTION(getProductsInfo, NULL),
        MAP_FUNCTION(removePurchaseFromQueue, NULL),

    };
    
    *numFunctionsToTest = sizeof(func) / sizeof(FRENamedFunction);
    *functionsToSet = func;
    _AirInAppPurchaseContext = ctx;
    
    if ((AirInAppPurchase*)AirInAppRefToSelf == nil)
    {
        AirInAppRefToSelf = [[AirInAppPurchase alloc] init];
    }

    NSLog(@"Exiting ContextInitializer()");
}

/* ContextFinalizer()
 * The context finalizer is called when the extension's ActionScript code
 * calls the ExtensionContext instance's dispose() method.
 * If the AIR runtime garbage collector disposes of the ExtensionContext instance, the runtime also calls ContextFinalizer().
 */
void AirInAppPurchaseContextFinalizer(FREContext ctx) 
{
    NSLog(@"Entering ContextFinalizer()");

    // Nothing to clean up.
    NSLog(@"Exiting ContextFinalizer()");
    return;
}


/* This is a TEST function that is being included as part of this template. 
 *
 * Users of this template are expected to change this and add similar functions 
 * to be able to call the native functions in the ANE from their ActionScript code
 */
ANE_FUNCTION(isInAppPurchaseSupported)
{
    NSLog(@"Entering IsSupported()");
    
    FREObject fo;
    
    FREResult aResult = FRENewObjectFromBool(YES, &fo);
    if (aResult == FRE_OK)
    {
        NSLog(@"Result = %d", aResult);
    }
    else
    {
        NSLog(@"Result = %d", aResult);
    }
    
	NSLog(@"Exiting IsSupported()");    
	return fo;
}


ANE_FUNCTION(AirInAppPurchaseInit)
{
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "LOGGING", (uint8_t*) "AirInAppPurchaseInit");
    
    [(AirInAppPurchase*)AirInAppRefToSelf registerObserver];
    
    return nil;
}
ANE_FUNCTION(makePurchase)
{
    uint32_t stringLength;
    const uint8_t *string1;
    //FREDispatchStatusEventAsync(context, (uint8_t*) "DEBUG", (uint8_t*) [@"purchase: getting product id" UTF8String]);
    
    if (FREGetObjectAsUTF8(argv[0], &stringLength, &string1) != FRE_OK)
    {
        return nil;
    }
    
    //FREDispatchStatusEventAsync(context, (uint8_t*) "DEBUG", (uint8_t*) [@"purchase: convert product id" UTF8String]);
    
    NSString *productIdentifier = [NSString stringWithUTF8String:(char*)string1];
    
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "DEBUG", (uint8_t*) [productIdentifier UTF8String]);
    AirInAppPurchase* inAppPurchase = (AirInAppPurchase*) AirInAppRefToSelf;
    SKProduct* skProduct = [inAppPurchase.productsDic valueForKey:productIdentifier];
    
    //paymentWithProductIdentifier 將被棄用改用 paymentWithProduct
    SKPayment* payment = [SKPayment paymentWithProduct:skProduct];//[SKPayment paymentWithProductIdentifier:productIdentifier];
    
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "DEBUG", (uint8_t*) [[payment productIdentifier] UTF8String]);
    
    //   [[SKPaymentQueue defaultQueue] removeTransactionObserver:self];
    
    
    [[SKPaymentQueue defaultQueue] addPayment:payment];
    
    return nil;
}
ANE_FUNCTION(userCanMakeAPurchase)
{
    
    BOOL canMakePayment = [SKPaymentQueue canMakePayments];
    
    if (canMakePayment)
    {
        FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "PURCHASE_ENABLED", (uint8_t*) [@"Yes" UTF8String]);
        
    } else
    {
        FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "PURCHASE_DISABLED", (uint8_t*) [@"No" UTF8String]);
    }
    return nil;
}
ANE_FUNCTION(getProductsInfo)
{
    FREObject arr = argv[0]; // array
    uint32_t arr_len; // array length
    
    FREGetArrayLength(arr, &arr_len);
    
    NSMutableSet* productsIdentifiers = [[NSMutableSet alloc] init];
    
    for(int32_t i=arr_len-1; i>=0;i--){
        
        // get an element at index
        FREObject element;
        FREGetArrayElementAt(arr, i, &element);
        
        // convert it to NSString
        uint32_t stringLength;
        const uint8_t *string;
        FREGetObjectAsUTF8(element, &stringLength, &string);
        NSString *productIdentifier = [NSString stringWithUTF8String:(char*)string];
        FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "LOGGING", (uint8_t*) [[NSString stringWithFormat:@"get product info: %@", productIdentifier] UTF8String]);
        [productsIdentifiers addObject:productIdentifier];
    }
    
    SKProductsRequest* request = [[SKProductsRequest alloc] initWithProductIdentifiers:productsIdentifiers];
    
    
    [(AirInAppPurchase*)AirInAppRefToSelf sendRequest:request AndContext:_AirInAppPurchaseContext];
    
    
    return nil;
}
ANE_FUNCTION(removePurchaseFromQueue)
{
    uint32_t stringLength;
    const uint8_t *string1;
    if (FREGetObjectAsUTF8(argv[0], &stringLength, &string1) != FRE_OK)
    {
        return nil;
    }
    
    NSString *productIdentifier = [NSString stringWithUTF8String:(char*)string1];
    
    FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "DEBUG", (uint8_t*) [[NSString stringWithFormat:@"removing purchase from queue %@", productIdentifier] UTF8String]);
    
    NSArray* transactions = [[SKPaymentQueue defaultQueue] transactions];
    
    for (SKPaymentTransaction* transaction in transactions)
    {
        //   FREDispatchStatusEventAsync(context, (uint8_t*) "DEBUG", (uint8_t*) [[NSString stringWithFormat:@"%@", [transaction transactionState]] UTF8String]);
        
        FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "DEBUG", (uint8_t*) [[[transaction payment] productIdentifier] UTF8String]);
        
        switch ([transaction transactionState]) {
            case SKPaymentTransactionStatePurchased:
                FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"SKPaymentTransactionStatePurchased" UTF8String]);
                break;
            case SKPaymentTransactionStateFailed:
                FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"SKPaymentTransactionStateFailed" UTF8String]);
                break;
            case SKPaymentTransactionStatePurchasing:
                FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"SKPaymentTransactionStatePurchasing" UTF8String]);
            case SKPaymentTransactionStateRestored:
                FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"SKPaymentTransactionStateRestored" UTF8String]);
            default:
                FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*)"DEBUG", (uint8_t*) [@"Unknown Reason" UTF8String]);
                break;
        }
        
        if ([transaction transactionState] == SKPaymentTransactionStatePurchased && [[[transaction payment] productIdentifier] isEqualToString:productIdentifier])
        {
            // conclude the transaction
            [[SKPaymentQueue defaultQueue] finishTransaction:transaction];
            FREDispatchStatusEventAsync(_AirInAppPurchaseContext, (uint8_t*) "DEBUG", (uint8_t*) [@"Conluding transaction" UTF8String]);
            break;
        }
    }
    
    return nil;

}

