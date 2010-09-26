module L06.JsonParser where

import Prelude hiding (exponent)
import Numeric
import Data.Char
import Control.Applicative
import Control.Monad
import L01.Validation
import L03.Parser
import L06.JsonValue
import L06.MoreParser

jsonString ::
  Parser String
jsonString =
  let c =     (is '\\' >> e)
          ||| satisfyAll [(/= '"'), (/= '\\')]
      e =     '"'  <$ is '"'
          ||| '\\' <$ is '\\'
          ||| '/'  <$ is '/'
          ||| '\b' <$ is 'b'
          ||| '\f' <$ is 'f'
          ||| '\n' <$ is 'n'
          ||| '\r' <$ is 'r'
          ||| '\t' <$ is 't'
          ||| is 'u' *> u
      u = do d <- replicateM 4 (satisfy isHexDigit)
             let z = fst . head . readHex $ d
             if z <= (fromEnum (maxBound :: Char))
                then pure (toEnum z)
                else failed ("Expected valid character. Found: " ++ [chr z])
  in betweenCharTok '"' '"' (list c)

jsonNumber ::
  Parser Rational
jsonNumber =
  P (\i -> case readSigned readFloat i of [] -> Error "Expected Rational"
                                          ((n, z):_) -> Value (z, n))

jsonObject ::
  Parser Assoc
jsonObject =
  let field = (,) <$> (jsonString <* charTok ':') <*> jsonValue
  in betweenCharTok '{' '}' $ field `sepby` charTok ','

jsonArray ::
  Parser [JsonValue]
jsonArray =
  betweenCharTok '[' ']' $ jsonValue `sepby` charTok ','

jsonTrue
  :: Parser String
jsonTrue =
  stringTok "true"

jsonFalse
  :: Parser String
jsonFalse =
  stringTok "false"

jsonNull
  :: Parser String
jsonNull =
  stringTok "null"

jsonValue ::
  Parser JsonValue
jsonValue =
      spaces *>
      (JsonNull <$ jsonNull
   ||| JsonTrue <$ jsonTrue
   ||| JsonFalse <$ jsonFalse
   ||| JsonArray <$> jsonArray
   ||| JsonString <$> jsonString
   ||| JsonObject <$> jsonObject
   ||| JsonRational False <$> jsonNumber)

readJsonValue ::
  FilePath -> IO JsonValue
readJsonValue p =
  do c <- readFile p
     case jsonValue <.> c of
       Error m -> error m
       Value a -> return a

