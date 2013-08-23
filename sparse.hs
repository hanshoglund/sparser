
{-# LANGUAGE GeneralizedNewtypeDeriving,
    OverloadedStrings,
    TypeOperators,
    DeriveFunctor,
    DeriveFoldable,
    FlexibleInstances
    #-}


module Sparse where

import Data.String
import Data.Semigroup
import Data.Foldable(Foldable)
import Control.Applicative
import Control.Monad.Plus

-- TODO
instance Semigroup (Partial a b) where (<>) = mplus






newtype a ?-> b = PartialP { getPartialP :: a -> Maybe (a, b) }
    
instance Functor ((?->) r) where
    fmap f (PartialP g) = PartialP (fmap (fmap f) . g)

instance Monad ((?->) r) where
    return x = PartialP (\a -> Just (a, x))
    PartialP f >>= k = PartialP $ \r -> (f r >>= \(r1, x) -> getPartialP (k x) r1)

instance MonadPlus ((?->) r) where
    mzero = PartialP (const Nothing)
    PartialP f `mplus` PartialP g = PartialP $ \x -> f x `mplus` g x

instance Applicative ((?->) r) where
    pure  = return
    (<*>) = ap

instance Alternative ((?->) r) where
    empty = mzero
    (<|>) = mplus

instance Semigroup ((?->) a b) where
    (<>) = mplus

instance Monoid ((?->) a b) where
    mempty  = mzero
    mappend = mplus

-- TODO FlexibleInstances
instance IsString (String ?-> String) where
    fromString = string

-- newtype SparseT a b = SparseT { getSparseT :: a ?-> b }
type SparseT = (?->)
    -- deriving (Semigroup, Monoid, Functor, Applicative, Alternative, Monad, MonadPlus)

type Sparse = SparseT String

runSparseT :: SparseT a b -> a -> Maybe b
runSparseT = fmap (fmap snd) . getPartialP

runSparseT' :: SparseT a b -> a -> Maybe (a, b)
runSparseT' = getPartialP

runSparse :: Sparse a -> String -> Maybe a
runSparse = runSparseT

----------


headP :: (a -> Bool) -> [a] -> Maybe ([a], a)
headP p []     = Nothing
headP p (x:xs) = if not (p x) then Nothing else Just (xs, x)

splitN :: ([a] -> Int) -> [a] -> Maybe ([a], [a])
splitN p [] = Nothing
splitN p ys = let n = p ys in if n < 1 then Nothing else Just (drop n ys, take n ys)

----------

char :: Char -> Sparse Char
char c = charIs (== c)

charIs :: (Char -> Bool) -> Sparse Char
charIs p = PartialP $ headP p

string :: String -> Sparse String
string s = stringIs (length s) (== s)

stringIs :: Int -> (String -> Bool) -> Sparse String
stringIs n p = PartialP $ splitN (\xs -> if p (take n xs) then n else 0)

asSparse = id
asSparse :: Sparse a -> Sparse a

----------

optionally x p          = p <|> return x
optionallyMaybe p       = optionally Nothing (liftM Just p)
optional p          = do{ p; return ()} <|> return ()
between open close p
                    = do{ open; x <- p; close; return x }
skipMany1 p         = do{ p; skipMany p }
skipMany p          = scan
                    where
                      scan  = do{ p; scan } <|> return ()
many1 p             = do{ x <- p; xs <- many p; return (x:xs) }
sepBy p sep         = sepBy1 p sep <|> return []
sepBy1 p sep        = do{ x <- p
                        ; xs <- many (sep >> p)
                        ; return (x:xs)
                        }
sepEndBy1 p sep     = do{ x <- p
                        ; do{ sep
                            ; xs <- sepEndBy p sep
                            ; return (x:xs)
                            }
                          <|> return [x]
                        }
sepEndBy p sep      = sepEndBy1 p sep <|> return []
endBy1 p sep        = many1 (do{ x <- p; sep; return x })
endBy p sep         = many (do{ x <- p; sep; return x })
count n p           | n <= 0    = return []
                    | otherwise = sequence (replicate n p)

----------


-- test :: Sparse [String]
test = asSparse $ string "hans" >> many1 (string ";")




single x = [x]
list z f xs = case xs of
    [] -> z
    ys -> f ys

[a,b,c,d,e,f,g,x,y,z,m,n,o,p,q,r] = undefined