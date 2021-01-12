// testing the fib functionality on js first. Going to try on Solidity tomorrow

const places = [1,2,3,4,5,6,7,8,9,10]
const stake = 0

function buildDistributions(
    _depositsArray,
    _stake
  )
  {
    prizeModel = buildFibPrizeModel(_depositsArray);
    let distributions = [];
    for (i=0; i<prizeModel.length; i++) {
       distribution = _stake + prizeModel[i];
      distributions.push(distribution);
    }
    console.log(distributions)
    return distributions
  }

  function buildFibPrizeModel(
     _array
    )
  {
    var fib = [];
    for ( i=0; i<_array.length; i++) {
      if (fib.length == 0) {
        fib.push(1-(1/_array.length));
      } else if (fib.length == 1) {
        fib.push(2);
      } else {
        nextFib = fib[i-1]/_array.length/5 + fib[i-2]; // as "5" increases, more winnings go towards the top quartile
        fib.push(nextFib);
      }
    }
    var fibSum = getArraySum(fib);
    for ( i=0; i<fib.length; i++) {
     fib[i] = fib[i]/fibSum/fib.length;
   }
   console.log('fib is, ', fib) 
   return fib;
  }

function getArraySum(
   _array
)
{
  var sum_ = 0;
  for ( i=0; i<_array.length; i++) {
    sum_ += _array[i];
  }
  console.log(sum_)
  return sum_
}

const distributions = buildDistributions(places, stake);
getArraySum(distributions)