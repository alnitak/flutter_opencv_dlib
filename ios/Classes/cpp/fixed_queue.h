#ifndef FIXED_QUEUE_H
#define FIXED_QUEUE_H

#include <cmath>
#include <cstdint>
#include <deque>
#include <iostream>
#include <vector>

// TODO optimize this
class FixedQueue {
public:
    FixedQueue() {};

    int getQueueSize() { return queue.size(); };

    static int getSize() { return m_size; };

    static void setSize(int size) { m_size = size; };

    void add(std::vector<int32_t> points, int32_t delta = 0) {
        if (queue.size() > m_size) {
            queue.pop_back();
        }
        queue.push_front(points);
        if (testShifting(delta))
            queue.push_front(points);
    }

    std::vector<int32_t> last() {
        return queue.front();
    }

    // test the last and the first in queue. If the position
    // excedes [delta], remove all entries
    bool testShifting(int32_t delta) {
        // just test the first X position
        if (queue.size() < 2 || delta == 0) return false;
        int32_t x1 = queue[queue.size()-1].at(0);
        int32_t x2 = queue[0].at(0);
        int32_t y1 = queue[queue.size()-1].at(1);
        int32_t y2 = queue[0].at(1);
        bool ret = false;
        if (std::abs(x2-x1) >= delta || std::abs(y2-y1) >= delta) {
            ret = true;
            queue.clear();
        }
        return ret;
    }

    std::vector<int32_t> average() {
        if (queue.size() == 0) return std::vector<int32_t>();
        if (queue.size() == 1) return queue[0];

        std::vector<int32_t> ret;
        for (size_t k=0; k<queue[0].size(); k++) {
            int64_t average = 0;

            for (size_t i=0; i<queue.size(); i++) {
                average += queue[i].at(k);
            }

            average /= queue.size();
            ret.push_back(average);
        }
        return ret;
    }

private:
    static std::size_t m_size;
    std::deque<std::vector<int32_t>> queue;
};


#endif // FIXED_QUEUE_H
