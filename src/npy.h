#include <iostream>
#include <string>
#include <vector>

namespace shoz {

class Npy {
//CONSTANT:
public:
    enum {
        //mDtype
        NONE    = 0,
        INTEGER,
        FLOAT,
        COMPLEX,
 
        //mEndian
        LITTLE_ENDIAN = 0,
        BIG_ENDIAN
    };

//TYPE
    typedef std::vector<int> defShape;

//LIFECYCLE:
public:
    Npy()
    : mDtype(NONE), mDwidth(1), mEndian(LITTLE_ENDIAN), mFortranOrder(false), mFlatLength(0), mData(nullptr)
    {}

    Npy(std::string filename) {
        Load(filename);
    }
    
    Npy(std::istream& in) {
        Load(in);
    }

    ~Npy() {
      delete[] mData;
    }

//ACTION:
public:
    void Load(std::istream& in);
    void Load(std::string filename);

    void Save(std::ostream& out);
    void Save(std::string filename);
    
    void Reshape(defShape shape);

//ACCESSOR:
public:
    int GetDtype() {
        return mDtype;
    }
    int GetDwidth() {
        return mDwidth;
    }
    int GetEndian() {
        return mEndian;
    }
    bool GetFortranOrder() {
        return mFortranOrder;
    }
    defShape GetShape() {
        return mShape;
    }
    char* GetData() {
        return mData;
    }
    size_t GetFlatSize() {
        return mDwidth * mFlatLength;
    }

//INQUIRY:
public:

//HELPER:
private:
    bool readDescr(const std::string& header);
    bool readFortranOrder(const std::string& header);
    bool readShape(const std::string& header);
    
    std::string strDescr();
    std::string strFortranOrder();
    std::string strShape();

    static size_t flat_size(const defShape& shape);

//ATTRIBUTE:
private:
    int     mDtype;
    int     mDwidth;
    int     mEndian;
    bool    mFortranOrder;
    defShape mShape;
    size_t   mFlatLength;
    char*   mData;
};

std::istream& operator>>(std::istream& in, Npy& npy);
std::ostream& operator<<(std::ostream& out, Npy& npy);
}
