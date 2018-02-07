#ERC721 Implementation

This project, really just the file `ERC721Deed.sol` implements the latest draft of the ERC721 standard (all 3 interfaces).

It is based on the OpenZeppelin implementation `ERC721Token` -- it adapts that code to work with the latest nomenclature and new functionality.

Feel free to flag issues and make Pull Requests if something looks amiss.

##TODO

One of the functions is left to the child to implement (`deedURI`) and the last Enumerable function is not yet implemented. It might make sense to leave that to children as well.
