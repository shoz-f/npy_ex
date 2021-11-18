#include <npy.h>
#include <string.h>
#include <fstream>
#include <sstream>
#include <regex>
#include <numeric>
#include <stdexcept>


#include <iostream>

namespace shoz {

void Npy::Load(std::istream& in)
{
    char magic[6];
    in.read(magic, sizeof(magic));
    if (memcmp("\x93NUMPY", magic, sizeof(magic)) != 0) {
        throw std::runtime_error("Npy: invalid magic");
    }

    char major, minor;
    in.get(major).get(minor);

    union {
        unsigned short S;
        char  C[2];
    } sz_header;
    in.get(sz_header.C[0]).get(sz_header.C[1]);

    std::string header;
    std::getline(in, header);
    if (header.length() + 1 != sz_header.S) {
        throw std::runtime_error("Npy: invalid header");
    }
    
    // parse header
    if (!readDescr(header)
    ||  !readFortranOrder(header)
    ||  !readShape(header)) {
        throw std::runtime_error("Npy: fail to parse header");
    }

    int size = mDwidth * mFlatLength;
    mData = new char[size];
    in.read(mData, size);
}

void Npy::Load(std::string filename)
{
    std::ifstream file(filename, std::ios_base::binary);
    Load(file);
}

bool Npy::readDescr(const std::string& header)
{
    std::smatch m;
    const std::regex re(R"('descr': '([<=>]?)([ifc])(\d?)')");
    std::regex_search(header, m, re);
    if (m.size() != 4) { return false; }

    mEndian = (m[1] == ">") ? BIG_ENDIAN : LITTLE_ENDIAN;
    mDtype  = (m[2] == "i") ? INTEGER
            : (m[2] == "f") ? FLOAT
            : (m[2] == "c") ? COMPLEX
            : NONE;
    mDwidth  = (m[3] == "") ? 1 : stoi(m[3].str());
    return true;
}

bool Npy::readFortranOrder(const std::string& header)
{
    std::smatch m;
    const std::regex re(R"('fortran_order': (True|False))");
    std::regex_search(header, m, re);
    if (m.size() != 2) { return false; }
    
    mFortranOrder = (m[1] == "True");
    return true;
}

bool Npy::readShape(const std::string& header)
{
    std::smatch m;
    const std::regex re(R"('shape': \(\s*(\d+[^)]*)\))");
    std::regex_search(header, m, re);
    if (m.size() != 2) { return false; }

    const std::regex re_digits(R"(\d+)");
    for (std::sregex_iterator num(m[1].first, m[1].second, re_digits), end; num != end; num++) {
        mShape.push_back(stoi(num->str()));
    }
    
    if (!mShape.empty()) {
        mFlatLength = flat_size(mShape);
        return true;
    }
    else {
        mFlatLength = 0;
        return false;
    }
}

void Npy::Save(std::ostream& out)
{
    out.write("\x93NUMPY", 6);  // magic
    out.put(1).put(0);         // version=1.0
    
    //make header
    std::ostringstream header;
    header << '{';
    header << "'descr': " << strDescr() << ", ";
    header << "'fortran_order': " << strFortranOrder() << ", ";
    header << "'shape': " << strShape() << ", ";
    header << '}';
    
    size_t padding = 0x7f - (10 + header.str().length()) % 0x80;
    header << std::string(padding, ' ');

    header << '\x0A';

    size_t sz_header = header.str().size();
    out.put(sz_header & 0xff).put((sz_header >> 8) & 0xff);
    out.write(header.str().c_str(), sz_header);
  
    int size = mDwidth * mFlatLength;
    out.write(mData, size);
}

void Npy::Save(std::string filename)
{
    std::ofstream file(filename, std::ios_base::binary);
    Save(file);
}

std::string Npy::strDescr()
{
	std::string descr;
	return descr.append("'")
                 .append((mEndian == BIG_ENDIAN) ? ">" : "<")
                 .append((mDtype == COMPLEX) ? "c" : (mDtype == FLOAT) ? "f" : "i")
                 .append(std::to_string(mDwidth))
                 .append("'")
	             ;
}

std::string Npy::strFortranOrder()
{
	return (mFortranOrder) ? "True" : "False";
}

std::string Npy::strShape()
{
	std::string shape;
	
    auto item = mShape.begin();
	shape.append("(").append(std::to_string(*item++));
	if (mShape.size() == 1) {
	    shape.append(",");
	}
	else while (item < mShape.end()) {
        shape.append(", ").append(std::to_string(*item++));
	}
    shape.append(")");

	return shape;
}

void Npy::Reshape(defShape shape)
{
    size_t new_size = flat_size(shape);

    if (new_size == mFlatLength) {
        mShape = shape;
    }
    else if (new_size < mFlatLength && (mFlatLength % new_size) == 0) {
        mShape = shape;
        mShape.push_back(mFlatLength/new_size);
    }
}


size_t Npy::flat_size(const defShape& shape)
{
    return std::accumulate(shape.begin(), shape.end(), 1, [](int acc, int i) { return acc*i; });
}

std::istream& operator>>(std::istream& in, Npy& npy)
{
    npy.Load(in);
    return in;
}

std::ostream& operator<<(std::ostream& out, Npy& npy)
{
    npy.Save(out);
    return out;
}

}