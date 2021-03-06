module Main where

import Bazaari.Types
import Bazaari.Http
import Data.Monoid
import Data.CountryCodes
import Data.ByteString
import System.Environment
import Data.Time
import Test.Hspec
import Text.Email.Validate
import Network.HTTP.Simple
import Network.HTTP.Types.URI
import qualified Data.ByteString.Lazy as LB
       (toStrict
       ,ByteString)

sample_ShipmentRequestDetails :: ShipmentRequestDetails
sample_ShipmentRequestDetails =
  ShipmentRequestDetails
    { amazonOrderId = AmazonOrderId "EYV-5491653-2834512"
    , sellerOrderId = Nothing
    , itemList =
      [ Item { orderItemId = OrderItemId "456", quantity = 2 }
      , Item { orderItemId = OrderItemId "789", quantity = 1 } ]
    , shipFromAddress =
        Address
          { name = AddressName "Leslie Generic"
          , addressLine1 = AddressLine "123 Anywhere Dr"
          , addressLine2 = Nothing
          , addressLine3 = Nothing
          , districtOrCounty = Nothing
          , email = unsafeEmailAddress "leslie_generic_1234" "somesite.com"
          , city = City "Somewheresville"
          , stateOrProvinceCode = Just $ State "FL"
          , postalCode = PostalCode "33133"
          , countryCode = US
          , phone = PhoneNumber "123-456-7890" }
    , packageDimensions = PredefinedDimensions FedEx_Tube
    , weight = 
        Weight
          { value = WeightValue 30.5
          , units = Ounces }
    , mustArriveByUTCTime =
        parseTimeM True defaultTimeLocale
          "%D %R"
          "08/15/16 12:30"
    , requestShipUTCTime = Nothing
    , requestShippingServiceOptions =
        ShippingServiceOptions
          { deliveryExperience = 
              DeliveryConfirmationWithAdultSignature
          , declaredValue = Just $
              CurrencyAmount
                { currencyCode = USD
                , amount = 44.99 }
          , carrierWillPickUp = True } }

sample_QueryString :: IO (ByteString, UTCTime)
sample_QueryString = do
  now <- getCurrentTime
  sellerId <- envBS "MWS_SELLER_ID"
  accessKeyId <- envBS "MWS_DEV_ACCESS_KEY_ID"
  return ( "POST\nmws.amazonservices.com\n/MerchantFulfillment/2015-06-01\nAWSAccessKeyId="
        <> accessKeyId
        <> "&Action=GetEligibleShippingServices&SellerId="
        <> sellerId
        <> "&ShipmentRequestDetails.AmazonOrderId=EYV-5491653-2834512&ShipmentRequestDetails.ItemList.Item.1.OrderItemId=456&ShipmentRequestDetails.ItemList.Item.1.Quantity=2&ShipmentRequestDetails.ItemList.Item.2.OrderItemId=789&ShipmentRequestDetails.ItemList.Item.2.Quantity=1&ShipmentRequestDetails.MustArriveByUTCTime=2016-08-15T12%3A30%3A00.00Z&ShipmentRequestDetails.PackageDimensions.PredefinedPackageDimensions=FedEx_Tube&ShipmentRequestDetails.ShipFromAddress.AddressLine1=123%20Anywhere%20Dr&ShipmentRequestDetails.ShipFromAddress.City=Somewheresville&ShipmentRequestDetails.ShipFromAddress.CountryCode=US&ShipmentRequestDetails.ShipFromAddress.Email=leslie_generic_1234%40somesite.com&ShipmentRequestDetails.ShipFromAddress.Name=Leslie%20Generic&ShipmentRequestDetails.ShipFromAddress.Phone=123-456-7890&ShipmentRequestDetails.ShipFromAddress.PostalCode=33133&ShipmentRequestDetails.ShipFromAddress.StateOrProvinceCode=FL&ShipmentRequestDetails.ShippingServiceOptions.CarrierWillPickUp=true&ShipmentRequestDetails.ShippingServiceOptions.DeclaredValue.Amount=44.99&ShipmentRequestDetails.ShippingServiceOptions.DeclaredValue.CurrencyCode=USD&ShipmentRequestDetails.ShippingServiceOptions.DeliveryExperience=DeliveryConfirmationWithAdultSignature&ShipmentRequestDetails.Weight.Unit=ounces&ShipmentRequestDetails.Weight.Value=30.5&SignatureMethod=HmacSHA256&SignatureVersion=2&Timestamp="
        <> ( urlEncode True . renderUTCTime $ now )
        <>  "&Version=2015-06-01", now)

envBS :: String -> IO ByteString
envBS envVar = renderEnvironmentVariable <$> getEnv envVar

sendRequest :: IO (Response LB.ByteString)
sendRequest = do
  (sk, sid, akid) <- getCreds
  getEligibleShippingServices NorthAmerica sk sid akid sample_ShipmentRequestDetails

makeRequest :: IO Request
makeRequest = do
  now <- getCurrentTime
  (sk, sid, akid) <- getCreds
  return $ getEligibleShippingServicesRequest
             NorthAmerica sk sid akid
               sample_ShipmentRequestDetails now

getCreds :: IO (ByteString, ByteString, ByteString)
getCreds = do
  sk <- envBS "MWS_DEV_SECRET_KEY"
  sid <- envBS "MWS_SELLER_ID"
  akid <- envBS "MWS_DEV_ACCESS_KEY_ID"
  return (sk, sid, akid)

main :: IO ()
main = hspec $ do
  describe "Unsigned Query" $ do
    it "Test ShipmentRequestDetails should produce a proper unsigned query string." $ do
      (str, now) <- sample_QueryString
      sellerId <- envBS "MWS_SELLER_ID"
      accessKeyId <- envBS "MWS_DEV_ACCESS_KEY_ID"
      getEligibleShippingServicesUnsigned NorthAmerica
        (getEligibleShippingServicesUnsignedParams
          sellerId accessKeyId sample_ShipmentRequestDetails now)
        `shouldBe` str
