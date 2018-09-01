
#include <iostream>
#include <fstream>
#include <cstdlib>

int main(int argc, char** argv)
{
  if (argc !=3)
    {
      std::cerr << "Usage: " << argv[0] << " <filename> <outfile prefix>" << std::endl;      
      exit(1);
    }

  std::cout << "Splitting file " << argv[1] << std::endl;

  std::string evenFile;
  evenFile = argv[2];
  evenFile += ".hi";

  std::string oddFile;
  oddFile = argv[2];
  oddFile += ".lo";

  std::ifstream is(argv[1]);
  std::ofstream evens(evenFile.c_str());
  std::ofstream odds(oddFile.c_str());

  bool even = true;

  char bytes[2];
  while (is)
    {
      is.read((char *)(bytes),2);
      if (even)
	{
	  evens.write((char *)(bytes),2);
	}
      else
	{
	  odds.write((char *)(bytes),2);
	}
      even = !even;
    }

  return 0;
}
